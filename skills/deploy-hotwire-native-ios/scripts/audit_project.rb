#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "uri"
require_relative "lib/deploy_ios_support"

options = {
  root: Dir.pwd,
  json: false,
  expect_clean_source: false
}

OptionParser.new do |parser|
  parser.banner = "Usage: audit_project.rb [options]"
  parser.on("--root PATH", "Application repository root") { |value| options[:root] = value }
  parser.on("--json", "Emit machine-readable JSON") { options[:json] = true }
  parser.on("--expect-clean-source", "Fail if the source checkout is dirty") { options[:expect_clean_source] = true }
  parser.on("--expect-bundle-id ID", "Require a bundle identifier") { |value| options[:bundle_id] = value }
  parser.on("--expect-team-id ID", "Require an Apple team identifier") { |value| options[:team_id] = value }
  parser.on("--expect-rails-origin URL", "Require a configured Rails origin") { |value| options[:rails_origin] = value }
end.parse!

begin
  root = Pathname.new(options[:root]).expand_path
  abort "Project root does not exist" unless root.directory?

  ignored_parts = %w[
    .agents .bundle .cache .claude .codex .cursor .gemini .git .gradle .opencode .swiftpm .windsurf
    DerivedData Pods build coverage log node_modules tmp vendor
  ].freeze

  ignored = lambda do |path|
    DeployIOSSupport.relative(root, path).split(File::SEPARATOR).any? { |part| ignored_parts.include?(part) }
  end

  files = lambda do |patterns|
    Array(patterns).flat_map do |pattern|
      Dir.glob(root.join(pattern).to_s, File::FNM_DOTMATCH)
    end.map { |path| Pathname.new(path) }.select(&:file?).reject { |path| ignored.call(path) }.uniq.sort
  end

  directories = lambda do |patterns|
    Array(patterns).flat_map do |pattern|
      Dir.glob(root.join(pattern).to_s, File::FNM_DOTMATCH)
    end.map { |path| Pathname.new(path) }.select(&:directory?).reject { |path| ignored.call(path) }.uniq.sort
  end

  relative = lambda { |path| DeployIOSSupport.relative(root, path) }

  xcode_projects = directories.call("**/*.xcodeproj")
  xcode_workspaces = directories.call("**/*.xcworkspace").reject do |path|
    path.to_s.include?(".xcodeproj#{File::SEPARATOR}project.xcworkspace")
  end
  project_files = xcode_projects.map { |project| project.join("project.pbxproj") }.select(&:file?)
  xcconfig_files = files.call("**/*.xcconfig")
  entitlements_files = files.call("**/*.entitlements")
  info_plists = files.call(["**/Info.plist", "**/*-Info.plist"])
  shared_schemes = files.call("**/xcshareddata/xcschemes/*.xcscheme")
  package_locks = files.call("**/Package.resolved")
  workflows = files.call([".github/workflows/*.yml", ".github/workflows/*.yaml"])

  configuration_text = (project_files + xcconfig_files).map do |path|
    content = DeployIOSSupport.safe_text(path)
    [path, content] if content
  end.compact

  assignment_values = lambda do |key|
    configuration_text.flat_map do |_, content|
      content.scan(/(?:^|[;\n])\s*#{Regexp.escape(key)}\s*=\s*([^;\n]+)/).flatten
    end.map { |value| value.strip.delete_prefix('"').delete_suffix('"') }.reject(&:empty?).uniq.sort
  end

  bundle_ids = assignment_values.call("PRODUCT_BUNDLE_IDENTIFIER")
  team_ids = assignment_values.call("DEVELOPMENT_TEAM").select { |value| value.match?(/\A[A-Z0-9]{10}\z/) }
  deployment_targets = assignment_values.call("IPHONEOS_DEPLOYMENT_TARGET")
  configurations = project_files.flat_map do |path|
    content = DeployIOSSupport.safe_text(path).to_s
    sections = content.scan(%r{/\* Begin XCBuildConfiguration section \*/(.*?)/\* End XCBuildConfiguration section \*/}m).flatten
    sections.flat_map do |section|
      section.scan(/isa = XCBuildConfiguration;.*?\bname = ([A-Za-z0-9_. -]+);/m).flatten
    end
  end.uniq.sort

  scheme_environment = shared_schemes.flat_map do |path|
    document = REXML::Document.new(path.read)
    document.elements.to_a("Scheme/LaunchAction/EnvironmentVariables/EnvironmentVariable").map do |variable|
      key = variable.attributes["key"].to_s
      value = variable.attributes["value"].to_s
      enabled = variable.attributes["isEnabled"].to_s.casecmp?("YES")
      item = {
        "scheme" => relative.call(path),
        "key" => key,
        "enabled" => enabled,
        "value_present" => !value.empty?
      }
      if key.match?(/(?:URL|ORIGIN|HOST)/i) && (uri = URI.parse(value)) && uri.is_a?(URI::HTTP) && uri.host
        item["origin"] = "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.default_port == uri.port}"
      end
      item
    rescue URI::InvalidURIError
      item
    end
  rescue REXML::ParseException
    [{"scheme" => relative.call(path), "parse_error" => true}]
  end

  entitlements = entitlements_files.map do |path|
    values = DeployIOSSupport.plist(path)
    {
      "file" => relative.call(path),
      "values" => DeployIOSSupport.selected_entitlements(values)
    }
  rescue DeployIOSSupport::Error
    {"file" => relative.call(path), "parse_error" => true}
  end

  origin_files = files.call(["**/*.swift", "**/*.xcconfig", "**/*.plist", "**/*.yml", "**/*.yaml"]).reject do |path|
    path_string = relative.call(path)
    path_string.match?(%r{(?:^|/)[^/]*(?:Tests?|UITests?)(?:/|$)}i) ||
      path_string.include?(".xcodeproj/") ||
      path_string.include?(".xcworkspace/")
  end
  origins = origin_files.flat_map do |path|
    content = DeployIOSSupport.safe_text(path)
    next [] unless content

    content.scan(%r{https?://[A-Za-z0-9.-]+(?::\d+)?}).uniq.map do |url|
      uri = URI.parse(url)
      next if %w[www.apple.com developer.apple.com guides.rubyonrails.org].include?(uri.host)

      {"file" => relative.call(path), "origin" => "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.default_port == uri.port}"}
    rescue URI::InvalidURIError
      nil
    end
  end.compact.uniq.sort_by { |item| [item["origin"], item["file"]] }
  release_origin_candidates = origins.reject do |item|
    uri = URI.parse(item.fetch("origin"))
    uri.scheme != "https" || uri.host == "localhost" || uri.host == "example.com" || uri.host.end_with?(".example.com")
  end

  generator_files = files.call(["**/project.yml", "**/Project.swift", "**/Tuist/ProjectDescriptionHelpers/*.swift"])
  fastlane_files = files.call(["**/Fastfile", "**/Appfile", "**/Matchfile", "**/Pluginfile"])
  bundler_files = files.call(["Gemfile", "Gemfile.lock"])

  workflow_evidence = workflows.map do |path|
    content = DeployIOSSupport.safe_text(path).to_s
    {
      "file" => relative.call(path),
      "uses_macos" => content.match?(/runs-on:\s*(?:\$\{\{[^}]+\}\}|["']?macos)/),
      "uses_xcodebuild" => content.include?("xcodebuild"),
      "uses_fastlane" => content.match?(/(?:bundle exec )?fastlane/),
      "references_secret_count" => content.scan(/\$\{\{\s*secrets\.[A-Za-z0-9_]+\s*\}\}/).uniq.length,
      "uses_pull_request_target" => content.match?(/^\s*pull_request_target\s*:/)
    }
  end

  signing_material = files.call([
    "**/*.cer", "**/*.key", "**/*.mobileprovision", "**/*.p12", "**/*.p8", "**/*.pem", "**/*.pfx",
    "**/*.provisionprofile"
  ])
  private_key_markers = ["PRIVATE KEY", "ENCRYPTED PRIVATE KEY", "RSA PRIVATE KEY", "EC PRIVATE KEY", "DSA PRIVATE KEY", "OPENSSH PRIVATE KEY"].map do |label|
    ["-----BEGIN", "#{label}-----"].join(" ")
  end
  private_key_files = files.call("**/*").select do |path|
    content = DeployIOSSupport.safe_text(path)
    content && private_key_markers.any? do |marker|
      content.match?(/#{Regexp.escape(marker)}[ \t]*\r?\n[A-Za-z0-9+\/=]{32,}/)
    end
  end
  signing_material = (signing_material + private_key_files).uniq.sort
  signing_material_types = signing_material.each_with_object(Hash.new(0)) do |path, counts|
    type = if private_key_files.include?(path)
      "private_key_content"
    else
      path.extname.downcase.delete_prefix(".")
    end
    counts[type] += 1
  end

  source = DeployIOSSupport.git_evidence(root)
  warnings = []
  warnings << "No Xcode project or workspace was found." if xcode_projects.empty? && xcode_workspaces.empty?
  warnings << "No shared Xcode scheme was found; CI cannot rely on a user-local scheme." if shared_schemes.empty?
  warnings << "No locked Swift package graph was found." if package_locks.empty?
  warnings << "Checked-in entitlements show the project request only; inspect the final signed artifact and profile before claiming a capability." unless entitlements.empty?
  scheme_environment.each do |variable|
    next unless variable["enabled"] && variable["origin"]&.match?(%r{\Ahttps?://(?:localhost|127\.0\.0\.1)(?::|\z)})

    warnings << "#{variable.fetch("scheme")} enables #{variable.fetch("key")} for localhost; a physical iPhone resolves that host to itself."
  end
  warnings << "A pull_request_target workflow exists. Never check out or run pull-request code in a job holding signing secrets." if workflow_evidence.any? { |item| item["uses_pull_request_target"] }
  warnings << "Potential signing material is present in the working tree; confirm it is not tracked." unless signing_material.empty?
  warnings << "The source checkout is dirty; record or commit the exact release input before distribution." if source["dirty"]

  checks = []
  checks << DeployIOSSupport.check("source checkout is clean", false, source["dirty"]) if options[:expect_clean_source]
  if options[:bundle_id]
    checks << DeployIOSSupport.check(
      "bundle identifier is configured",
      options[:bundle_id],
      bundle_ids,
      comparator: ->(expected, actual) { actual.include?(expected) }
    )
  end
  if options[:team_id]
    checks << DeployIOSSupport.check(
      "Apple team identifier is configured",
      options[:team_id],
      team_ids,
      comparator: ->(expected, actual) { actual.include?(expected) }
    )
  end
  if options[:rails_origin]
    checks << DeployIOSSupport.check(
      "Rails origin is configured",
      options[:rails_origin],
      origins.map { |item| item["origin"] },
      comparator: ->(expected, actual) { actual.include?(expected.sub(%r{/$}, "")) }
    )
  end
  checks << DeployIOSSupport.check("no signing material appears in the repository", 0, signing_material.length)

  report = {
    "schema_version" => 1,
    "kind" => "hotwire_native_ios_project_audit",
    "project" => File.basename(root),
    "source" => source,
    "decisions_requiring_owner_confirmation" => [
      "source owner",
      "Apple-team owner and intended team",
      "build machine/executor",
      "Rails environment/origin",
      "install channel",
      "capability under test"
    ],
    "xcode" => {
      "projects" => xcode_projects.map(&relative),
      "workspaces" => xcode_workspaces.map(&relative),
      "shared_schemes" => shared_schemes.map(&relative),
      "shared_scheme_environment" => scheme_environment,
      "configurations" => configurations,
      "project_generators" => generator_files.map(&relative),
      "package_locks" => package_locks.map(&relative)
    },
    "settings" => {
      "bundle_identifiers" => bundle_ids,
      "team_identifiers" => team_ids,
      "deployment_targets" => deployment_targets,
      "xcconfig_files" => xcconfig_files.map(&relative),
      "info_plists" => info_plists.map(&relative),
      "entitlements" => entitlements,
      "rails_origins" => origins,
      "release_origin_candidates" => release_origin_candidates
    },
    "automation" => {
      "workflows" => workflow_evidence,
      "fastlane_files" => fastlane_files.map(&relative),
      "bundler_files" => bundler_files.map(&relative)
    },
    "sensitive_material_scan" => {
      "candidate_count" => signing_material.length,
      "candidate_types" => signing_material_types
    },
    "warnings" => warnings,
    "checks" => checks
  }

  DeployIOSSupport.result_exit!(report, json: options[:json])
rescue DeployIOSSupport::Error => error
  warn DeployIOSSupport.redact_error(error, [root])
  exit 1
end
