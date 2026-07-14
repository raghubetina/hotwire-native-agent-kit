#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "pathname"

options = { root: Dir.pwd, json: false }
OptionParser.new do |parser|
  parser.banner = "Usage: audit_project.rb [--root PATH] [--json]"
  parser.on("--root PATH", "Project root") { |value| options[:root] = value }
  parser.on("--json", "Emit JSON") { options[:json] = true }
end.parse!

root = Pathname.new(options[:root]).expand_path
abort "Project root does not exist: #{root}" unless root.directory?

def read(path)
  path.file? ? path.read : nil
rescue Errno::EACCES, Encoding::InvalidByteSequenceError
  nil
end

def relative(root, path)
  path.relative_path_from(root).to_s
rescue ArgumentError
  path.to_s
end

IGNORED_DIRECTORIES = %w[
  .agents .bundle .cache .claude .codex .cursor .gemini .git .gradle .opencode .windsurf
  DerivedData Pods build coverage log node_modules tmp vendor
].freeze

def ignored_path?(root, path)
  relative(root, path).split(File::SEPARATOR).any? { |part| IGNORED_DIRECTORIES.include?(part) }
end

def glob_files(root, pattern)
  Dir.glob(root.join(pattern).to_s, File::FNM_DOTMATCH)
    .map { |path| Pathname.new(path) }
    .select(&:file?)
    .reject { |path| ignored_path?(root, path) }
end

def glob_directories(root, pattern)
  Dir.glob(root.join(pattern).to_s, File::FNM_DOTMATCH)
    .map { |path| Pathname.new(path) }
    .select(&:directory?)
    .reject { |path| ignored_path?(root, path) }
end

def gem_version(lock, name)
  lock&.match(/^ {4}#{Regexp.escape(name)} \(([^)]+)\)/)&.captures&.first
end

def package_dependencies(package_json)
  return {} unless package_json

  parsed = JSON.parse(package_json)
  ["dependencies", "devDependencies", "peerDependencies"].each_with_object({}) do |key, all|
    all.merge!(parsed[key] || {})
  end
rescue JSON::ParserError
  {}
end

def resolved_ios_versions(files)
  files.map do |path|
    parsed = JSON.parse(path.read)
    pins = parsed["pins"] || parsed.dig("object", "pins") || []
    pin = pins.find do |candidate|
      identity = candidate["identity"] || candidate["package"] || ""
      location = candidate["location"] || candidate["repositoryURL"] || ""
      identity.include?("hotwire-native-ios") || location.include?("hotwire-native-ios")
    end
    next unless pin

    state = pin["state"] || {}
    { "file" => path.to_s, "version" => state["version"], "revision" => state["revision"] }
  rescue JSON::ParserError
    nil
  end.compact
end

def ios_manifest_constraints(files)
  files.map do |path|
    content = read(path)
    next unless content&.include?("hotwire-native-ios")

    index = content.index("hotwire-native-ios")
    snippet = content[index, 500]
    kind = nil
    value = nil

    if (match = snippet.match(/\.upToNext(Major|Minor)\(from:\s*["']([^"']+)["']/))
      kind = "up_to_next_#{match[1].downcase}"
      value = match[2]
    elsif (match = snippet.match(/\.exact\(\s*["']([^"']+)["']/))
      kind = "exact"
      value = match[1]
    elsif (match = snippet.match(/\bfrom:\s*["']([^"']+)["']/))
      kind = "from"
      value = match[1]
    elsif (match = snippet.match(/\b(branch|revision):\s*["']([^"']+)["']/))
      kind = match[1]
      value = match[2]
    end

    { "file" => path.to_s, "kind" => kind || "unparsed", "value" => value }
  end.compact
end

def android_versions(files)
  versions = []

  files.each do |path|
    content = read(path)
    next unless content

    content.scan(/dev\.hotwire:(?:core|navigation-fragments):([0-9][A-Za-z0-9_.+\-]*)/) do |match|
      versions << { "file" => path.to_s, "version" => match.first }
    end

    next unless path.extname == ".toml" && content.include?("dev.hotwire")

    catalog = content.scan(/^\s*([A-Za-z0-9_.-]+)\s*=\s*["']([^"']+)["']/).to_h
    content.scan(/module\s*=\s*["']dev\.hotwire:(?:core|navigation-fragments)["'][^\n]*version\.ref\s*=\s*["']([^"']+)["']/) do |match|
      value = catalog[match.first]
      versions << { "file" => path.to_s, "version" => value } if value
    end
  end

  versions.uniq
end

def path_configuration_shape?(content)
  return false unless content

  keys = %w[settings rules]
  keys.all? do |key|
    escaped = Regexp.escape(key)
    content.match?(/["']#{escaped}["']\s*(?::|=>)/) ||
      content.match?(/\b#{escaped}\s*:/) ||
      content.match?(/\bjson\.#{escaped}\b/)
  end
end

def configuration_named?(path)
  path.to_s.match?(/(?:path[-_]?config(?:uration)?s?|client[-_]?configurations?|configurations?(?:_controller)?)(?=[.\/_:#,\s'"-]|$)/i)
end

def configuration_route?(content)
  return false unless content

  content.each_line.any? do |line|
    line.match?(/\b(?:resources?|get|match|scope|namespace)\b/) && configuration_named?(line)
  end
end

def strong_configuration_route?(content)
  return false unless content

  content.each_line.any? do |line|
    line.match?(/\b(?:resources?|get|match|scope|namespace)\b/) &&
      line.match?(/(?:path[-_]?config(?:uration)?s?|client[-_]?configurations?)/i)
  end
end

gemfile_lock_path = root.join("Gemfile.lock")
gemfile_lock = read(gemfile_lock_path)
package_json_path = root.join("package.json")
dependencies = package_dependencies(read(package_json_path))
importmap_path = root.join("config/importmap.rb")
importmap = read(importmap_path)

resolved_files = glob_files(root, "**/Package.resolved")
package_swift_files = glob_files(root, "**/Package.swift")
gradle_files = %w[**/*.gradle **/*.gradle.kts **/*.toml].flat_map { |pattern| glob_files(root, pattern) }.uniq
ios_versions = resolved_ios_versions(resolved_files)
ios_constraints = ios_manifest_constraints(package_swift_files)
android_dependency_versions = android_versions(gradle_files)

bridge_controllers = glob_files(root, "**/controllers/bridge/*_controller.js")
rails_view_root = root.join("app/views")
path_configs = glob_files(root, "**/*{path-configuration,path_configuration,configuration}*.json")
path_configs.concat(glob_files(root, "**/*.json").select { |path| path_configuration_shape?(read(path)) })
path_configs = path_configs.uniq.reject do |path|
  path.to_s.start_with?(rails_view_root.to_s + File::SEPARATOR)
end

rails_controller_files = glob_files(root, "app/controllers/**/*_controller.rb")
rails_view_files = %w[
  app/views/**/*.json
  app/views/**/*.json.erb
  app/views/**/*.json.builder
  app/views/**/*.json.jbuilder
].flat_map { |pattern| glob_files(root, pattern) }.uniq
rails_route_files = (glob_files(root, "config/routes.rb") + glob_files(root, "config/routes/**/*.rb")).uniq

path_configuration_views = rails_view_files.select do |path|
  configuration_named?(relative(root, path)) && path_configuration_shape?(read(path))
end
view_directories = path_configuration_views.map do |path|
  relative(rails_view_root, path.dirname)
end.uniq

path_configuration_controllers = rails_controller_files.select do |path|
  content = read(path)
  controller_name = path.basename("_controller.rb").to_s
  next false unless configuration_named?(relative(root, path))

  (content&.match?(/\brender\b/) && path_configuration_shape?(content)) ||
    view_directories.include?(controller_name)
end

implementation_evidence = []
path_configuration_controllers.each do |path|
  content = read(path)
  evidence = if path_configuration_shape?(content)
    "renders or defines JSON with settings/rules path-configuration keys"
  else
    "has a path-configuration-shaped Rails view"
  end
  implementation_evidence << {
    "file" => relative(root, path),
    "kind" => "rails_controller",
    "evidence" => evidence
  }
end
path_configuration_views.each do |path|
  implementation_evidence << {
    "file" => relative(root, path),
    "kind" => "rails_view",
    "evidence" => "template contains settings/rules path-configuration keys"
  }
end

route_evidence = rails_route_files.select do |path|
  content = read(path)
  strong_configuration_route?(content) || (!implementation_evidence.empty? && configuration_route?(content))
end.map do |path|
  {
    "file" => relative(root, path),
    "kind" => "rails_route",
    "evidence" => "declares a configuration-named Rails route"
  }
end

rails_path_configuration_evidence = (route_evidence + implementation_evidence).sort_by do |item|
  [item["file"], item["kind"]]
end
rails_endpoint_candidate = !route_evidence.empty? && !implementation_evidence.empty?
swift_files = glob_files(root, "**/*.swift")
kotlin_files = glob_files(root, "**/*.kt")
xcode_projects = glob_directories(root, "**/*.xcodeproj")
gradle_projects = %w[**/settings.gradle **/settings.gradle.kts].flat_map { |pattern| glob_files(root, pattern) }.uniq

ruby_app_files = %w[app/**/*.rb app/**/*.erb config/**/*.rb].flat_map { |pattern| glob_files(root, pattern) }
native_detection_files = ruby_app_files.select { |path| read(path)&.include?("hotwire_native_app?") || read(path)&.include?("turbo_native_app?") }

auth_gems = %w[devise rodauth omniauth webauthn jwt].select { |name| gem_version(gemfile_lock, name) }
web_bridge_version = dependencies["@hotwired/hotwire-native-bridge"]
web_bridge_version ||= importmap&.match(/pin\s+["']@hotwired\/hotwire-native-bridge["'][^\n]*/)&.to_s

result = {
  "root" => root.to_s,
  "verified_matrix" => {
    "hotwire_native_ios" => "1.3.0",
    "hotwire_native_android" => "1.3.0",
    "hotwire_native_bridge" => "1.2.2",
    "verified_on" => "2026-07-10"
  },
  "rails" => {
    "gemfile_lock" => gemfile_lock_path.file? ? relative(root, gemfile_lock_path) : nil,
    "rails" => gem_version(gemfile_lock, "rails"),
    "turbo_rails" => gem_version(gemfile_lock, "turbo-rails"),
    "authentication_gems" => auth_gems
  },
  "web" => {
    "package_json" => package_json_path.file? ? relative(root, package_json_path) : nil,
    "hotwire_native_bridge" => web_bridge_version,
    "stimulus" => dependencies["@hotwired/stimulus"],
    "turbo" => dependencies["@hotwired/turbo"] || dependencies["@hotwired/turbo-rails"],
    "bridge_controllers" => bridge_controllers.map { |path| relative(root, path) }
  },
  "ios" => {
    "xcode_projects" => xcode_projects.map { |path| relative(root, path) },
    "swift_files" => swift_files.length,
    "manifest_constraints" => ios_constraints.map { |item| item.merge("file" => relative(root, Pathname.new(item["file"]))) },
    "resolved_dependencies" => ios_versions.map { |item| item.merge("file" => relative(root, Pathname.new(item["file"]))) }
  },
  "android" => {
    "gradle_projects" => gradle_projects.map { |path| relative(root, path) },
    "kotlin_files" => kotlin_files.length,
    "resolved_dependencies" => android_dependency_versions.map { |item| item.merge("file" => relative(root, Pathname.new(item["file"]))) }
  },
  "integration" => {
    "path_configurations" => path_configs.map { |path| relative(root, path) },
    "rails_path_configuration" => {
      "endpoint_candidate" => rails_endpoint_candidate,
      "runtime_verified" => false,
      "evidence" => rails_path_configuration_evidence
    },
    "native_detection_files" => native_detection_files.map { |path| relative(root, path) }
  },
  "warnings" => []
}

warnings = result["warnings"]
warnings << "Gemfile.lock was not found; Rails compatibility is unknown." unless gemfile_lock
warnings << "turbo-rails was not detected in Gemfile.lock." if gemfile_lock && !result.dig("rails", "turbo_rails")
warnings << "The Hotwire Native web bridge was not detected in package.json or importmap." unless web_bridge_version
warnings << "No iOS project was detected." if xcode_projects.empty?
warnings << "Multiple iOS projects were detected; select the intended client before editing." if xcode_projects.length > 1
warnings << "No resolved hotwire-native-ios package was detected." if !xcode_projects.empty? && ios_versions.empty?
warnings << "No Android Gradle project was detected." if gradle_projects.empty?
warnings << "Multiple Android Gradle projects were detected; select the intended client before editing." if gradle_projects.length > 1
warnings << "No dev.hotwire Android dependency version was detected." if !gradle_projects.empty? && android_dependency_versions.empty?
if path_configs.empty? && rails_path_configuration_evidence.empty?
  warnings << "No bundled/static path-configuration JSON file or Rails endpoint evidence was detected."
elsif rails_endpoint_candidate
  warnings << "A Rails path-configuration endpoint candidate was found by static inspection only; verify its route, JSON response, public unauthenticated access, caching, and runtime behavior."
elsif !rails_path_configuration_evidence.empty?
  warnings << "Rails path-configuration evidence was found, but static inspection did not find both a route and a rendering controller/template; verify the endpoint at runtime."
end
warnings << "Native request detection was not found in Rails application/config files." if native_detection_files.empty?
ios_constraints.each do |constraint|
  if constraint["kind"] == "up_to_next_minor" && constraint["value"]&.start_with?("1.2.")
    warnings << "#{relative(root, Pathname.new(constraint['file']))} restricts Hotwire Native iOS to 1.2.x and excludes 1.3.0."
  end
end

if options[:json]
  puts JSON.pretty_generate(result)
  exit 0
end

puts "Hotwire Native project audit"
puts "Root: #{result['root']}"
puts "Verified matrix: iOS 1.3.0, Android 1.3.0, web bridge 1.2.2 (2026-07-10)"
puts
puts "Rails: #{result.dig('rails', 'rails') || 'not detected'}"
puts "turbo-rails: #{result.dig('rails', 'turbo_rails') || 'not detected'}"
puts "Web bridge: #{result.dig('web', 'hotwire_native_bridge') || 'not detected'}"
puts "Bridge controllers: #{bridge_controllers.length}"
puts "iOS projects: #{xcode_projects.length}; resolved Hotwire dependencies: #{ios_versions.map { |item| item['version'] || item['revision'] }.compact.join(', ').then { |value| value.empty? ? 'none' : value }}"
puts "Android projects: #{gradle_projects.length}; Hotwire dependencies: #{android_dependency_versions.map { |item| item['version'] }.compact.join(', ').then { |value| value.empty? ? 'none' : value }}"
puts "Path configuration files: #{path_configs.length}"
puts "Rails endpoint candidate: #{rails_endpoint_candidate ? 'yes (static evidence only)' : 'not confirmed'}; evidence files: #{rails_path_configuration_evidence.length}"
puts
if warnings.empty?
  puts "Warnings: none"
else
  puts "Warnings:"
  warnings.each { |warning| puts "- #{warning}" }
end
