#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "digest"
require "optparse"
require "time"
require "uri"
require_relative "lib/deploy_ios_support"

options = {
  json: false,
  allow_unsigned: false,
  expect_clean_source: false,
  architectures: [],
  associated_domains: [],
  nested_bundle_ids: [],
  max_extracted_bytes: 4 * 1024 * 1024 * 1024
}

parser = OptionParser.new do |arguments|
  arguments.banner = "Usage: inspect_artifact.rb [options] APP.app|APP.app.zip|APP.ipa|APP.xcarchive"
  arguments.on("--json", "Emit machine-readable JSON") { options[:json] = true }
  arguments.on("--allow-unsigned", "Permit an unsigned artifact (for Simulator checks)") { options[:allow_unsigned] = true }
  arguments.on("--expect-unsigned", "Require no Apple signing identity/profile; permit no or ad hoc signature") do
    options[:expect_unsigned] = true
    options[:allow_unsigned] = true
  end
  arguments.on("--expect-platform PLATFORM", %w[iphoneos iphonesimulator], "Require the built Apple platform") do |value|
    options[:platform] = value
  end
  arguments.on("--expect-architecture ARCH", "Require an architecture in every embedded executable; repeatable") do |value|
    options[:architectures] << value
  end
  arguments.on("--source-root PATH", "Repository used to build the artifact") { |value| options[:source_root] = value }
  arguments.on("--expect-clean-source", "Fail if --source-root is dirty") { options[:expect_clean_source] = true }
  arguments.on("--expect-source-sha SHA", "Require both --source-root and the artifact's embedded revision to be SHA") do |value|
    options[:source_sha] = value
  end
  arguments.on("--expect-artifact-sha256 SHA", "Require the artifact digest") { |value| options[:artifact_sha256] = value.downcase }
  arguments.on("--expect-certificate-sha256 SHA", "Require the leaf signing-certificate digest") { |value| options[:certificate_sha256] = value.downcase }
  arguments.on("--expect-bundle-id ID", "Require CFBundleIdentifier") { |value| options[:bundle_id] = value }
  arguments.on("--expect-nested-bundle-id ID", "Require a nested app or extension bundle ID; repeatable") do |value|
    options[:nested_bundle_ids] << value
  end
  arguments.on("--expect-team-id ID", "Require the signing team") { |value| options[:team_id] = value }
  arguments.on("--expect-version VERSION", "Require CFBundleShortVersionString") { |value| options[:version] = value }
  arguments.on("--expect-build-number NUMBER", "Require CFBundleVersion") { |value| options[:build_number] = value }
  arguments.on("--expect-channel CHANNEL", %w[development ad-hoc app-store-connect], "Require the provisioning channel") do |value|
    options[:channel] = value
  end
  arguments.on("--expect-aps-environment NAME", %w[development production], "Require APNs entitlement") do |value|
    options[:aps_environment] = value
  end
  arguments.on("--expect-associated-domain DOMAIN", "Require an Associated Domains entry; repeatable") do |value|
    options[:associated_domains] << value
  end
  arguments.on("--expect-profile-uuid UUID", "Require the embedded profile UUID") { |value| options[:profile_uuid] = value }
  arguments.on("--expect-rails-origin URL", "Require a baked application origin") { |value| options[:rails_origin] = value }
  arguments.on("--max-extracted-bytes BYTES", Integer, "Reject larger compressed-artifact payloads") do |value|
    options[:max_extracted_bytes] = value
  end
end
parser.parse!

abort "--max-extracted-bytes must be positive" unless options[:max_extracted_bytes].positive?
if options[:source_sha] && !options[:source_sha].match?(/\A[0-9a-f]{40}\z/i)
  abort "--expect-source-sha must be a full 40-character Git commit"
end
unless options[:architectures].all? { |value| value.match?(/\A[A-Za-z0-9_-]+\z/) }
  abort "--expect-architecture must name one architecture"
end
options[:architectures].uniq!

artifact_argument = ARGV.shift
abort parser.to_s unless artifact_argument && ARGV.empty?

artifact = Pathname.new(artifact_argument).expand_path
abort "Artifact does not exist" unless artifact.exist?

def normalized_origin(value)
  uri = URI.parse(value)
  return nil unless %w[http https].include?(uri.scheme) && uri.host && uri.userinfo.nil?
  return nil unless [nil, "", "/"].include?(uri.path) && uri.query.nil? && uri.fragment.nil?

  "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.default_port == uri.port}"
rescue URI::InvalidURIError
  nil
end

if options[:rails_origin] && !normalized_origin(options[:rails_origin])
  abort "--expect-rails-origin must be an absolute HTTP(S) host root without credentials, path, query, or fragment"
end

def origins_in(value)
  case value
  when Hash
    value.values.flat_map { |child| origins_in(child) }
  when Array
    value.flat_map { |child| origins_in(child) }
  when String
    origin = normalized_origin(value)
    origin ? [origin] : []
  else
    []
  end
end

def plist_from_command_output(stdout, stderr)
  combined = "#{stdout}\n#{stderr}"
  start = combined.index("<?xml") || combined.index("<plist")
  closing_tag = "</plist>"
  finish = combined.rindex(closing_tag)
  return {} unless start && finish

  DeployIOSSupport.plist(combined[start..(finish + closing_tag.length - 1)])
end

def validate_zip_entries!(archive, max_extracted_bytes, label:)
  names, = DeployIOSSupport.capture("zipinfo", "-1", archive)
  entries = names.lines(chomp: true)
  raise DeployIOSSupport::Error, "#{label} contains no entries" if entries.empty?
  raise DeployIOSSupport::Error, "#{label} contains too many entries" if entries.length > 100_000

  entries.each do |entry|
    raise DeployIOSSupport::Error, "#{label} contains an unsafe archive path" unless entry.valid_encoding?
    if entry.empty? || entry.include?("\0") || entry.include?("\\") || entry.start_with?("/", "~") || entry.match?(/\A[A-Za-z]:/)
      raise DeployIOSSupport::Error, "#{label} contains an unsafe archive path"
    end

    components = entry.split("/", -1)
    raise DeployIOSSupport::Error, "#{label} contains an unsafe archive path" if components.any? { |part| part == ".." }
  end

  long_listing, = DeployIOSSupport.capture("zipinfo", "-l", archive)
  if long_listing.lines.any? { |line| line.match?(/^l[rwxstST-]{9}\s/) }
    raise DeployIOSSupport::Error, "#{label} contains a symbolic link"
  end

  totals, = DeployIOSSupport.capture("zipinfo", "-t", archive)
  match = totals.match(/([0-9]+) bytes uncompressed/)
  raise DeployIOSSupport::Error, "Unable to determine the #{label.downcase}'s uncompressed size" unless match

  if Integer(match[1]) > max_extracted_bytes
    raise DeployIOSSupport::Error, "#{label} exceeds the extraction-size limit"
  end
end

def validate_extracted_tree!(root, label:)
  expanded_root = Pathname.new(root).realpath
  Dir.glob(expanded_root.join("**/*").to_s, File::FNM_DOTMATCH).each do |entry|
    next if [".", ".."].include?(File.basename(entry))

    stat = File.lstat(entry)
    raise DeployIOSSupport::Error, "Extracted #{label} contains a symbolic link" if stat.symlink?

    resolved_parent = Pathname.new(entry).parent.realpath
    unless resolved_parent == expanded_root || resolved_parent.to_s.start_with?(expanded_root.to_s + File::SEPARATOR)
      raise DeployIOSSupport::Error, "Extracted #{label} escaped its temporary directory"
    end
  end
end

def path_within?(root, candidate)
  root_path = root.realpath.to_s
  candidate_path = candidate.realpath.to_s
  candidate_path == root_path || candidate_path.start_with?(root_path + File::SEPARATOR)
rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
  false
end

def symlinked_path_component?(root, candidate)
  current = root
  return true if current.symlink?

  candidate.relative_path_from(root).each_filename.any? do |component|
    return true if component == ".."

    current = current.join(component)
    current.symlink?
  end
rescue ArgumentError
  true
end

def with_application(artifact, max_extracted_bytes)
  case artifact.extname.downcase
  when ".app"
    raise DeployIOSSupport::Error, "The .app artifact is not a directory" unless artifact.directory?
    raise DeployIOSSupport::Error, "The .app artifact must not be a symbolic link" if artifact.symlink?
    validate_extracted_tree!(artifact, label: "application")
    yield artifact, "app"
  when ".xcarchive"
    raise DeployIOSSupport::Error, "The .xcarchive artifact is not a directory" unless artifact.directory?
    raise DeployIOSSupport::Error, "The .xcarchive artifact must not be a symbolic link" if artifact.symlink?
    applications = Dir.glob(artifact.join("Products/Applications/*.app").to_s).select { |path| File.directory?(path) }
    raise DeployIOSSupport::Error, "Expected exactly one application in the xcarchive" unless applications.length == 1
    application = Pathname.new(applications.first)
    if symlinked_path_component?(artifact, application) || !path_within?(artifact, application)
      raise DeployIOSSupport::Error, "The archived application must remain inside the xcarchive without symbolic links"
    end
    validate_extracted_tree!(application, label: "archived application")
    yield application, "xcarchive"
  when ".ipa"
    raise DeployIOSSupport::Error, "The .ipa artifact is not a file" unless artifact.file?
    validate_zip_entries!(artifact, max_extracted_bytes, label: "IPA")
    Dir.mktmpdir("deploy-ios-ipa") do |tmp|
      DeployIOSSupport.capture("ditto", "-x", "-k", artifact, tmp)
      validate_extracted_tree!(tmp, label: "IPA")
      applications = Dir.glob(File.join(tmp, "Payload", "*.app")).select { |path| File.directory?(path) }
      raise DeployIOSSupport::Error, "Expected exactly one application in the IPA" unless applications.length == 1
      yield Pathname.new(applications.first), "ipa"
    end
  when ".zip"
    unless artifact.file? && artifact.basename.to_s.downcase.end_with?(".app.zip")
      raise DeployIOSSupport::Error, "Expected a file named APP.app.zip"
    end

    validate_zip_entries!(artifact, max_extracted_bytes, label: "Simulator app archive")
    Dir.mktmpdir("deploy-ios-app-zip") do |tmp|
      DeployIOSSupport.capture("ditto", "-x", "-k", artifact, tmp)
      validate_extracted_tree!(tmp, label: "Simulator app archive")
      payload_entries = Dir.children(tmp).reject { |name| name == "__MACOSX" }
      applications = payload_entries.each_with_object([]) do |name, matches|
        path = File.join(tmp, name)
        matches << path if name.end_with?(".app") && File.directory?(path)
      end
      unless payload_entries.length == 1 && applications.length == 1
        raise DeployIOSSupport::Error, "Expected only one top-level application in the Simulator app archive"
      end
      yield Pathname.new(applications.first), "app-zip"
    end
  else
    raise DeployIOSSupport::Error, "Expected a .app, .app.zip, .ipa, or .xcarchive artifact"
  end
end

def bundle_info(bundle)
  candidates = [
    bundle.join("Info.plist"),
    bundle.join("Resources/Info.plist"),
    bundle.join("Versions/Current/Resources/Info.plist")
  ]
  path = candidates.find(&:file?)
  path ? DeployIOSSupport.plist(path) : {}
end

def provisioning_profile(bundle)
  path = bundle.join("embedded.mobileprovision")
  return nil unless path.file?

  stdout, stderr, status = DeployIOSSupport.capture("security", "cms", "-D", "-i", path, allow_failure: true)
  raise DeployIOSSupport::Error, "Unable to decode an embedded provisioning profile" unless status.success?

  values = plist_from_command_output(stdout, stderr)
  developer_certificate_sha256s = Array(values["DeveloperCertificates"]).each_with_object([]) do |certificate, digests|
    decoded = Base64.strict_decode64(certificate.to_s.gsub(/\s+/, ""))
    digests << Digest::SHA256.hexdigest(decoded)
  rescue ArgumentError
    nil
  end

  {
    "sha256" => Digest::SHA256.file(path).hexdigest,
    "uuid" => values["UUID"],
    "team_identifiers" => Array(values["TeamIdentifier"]),
    "application_identifier_prefixes" => Array(values["ApplicationIdentifierPrefix"]),
    "creation_date" => values["CreationDate"],
    "expiration_date" => values["ExpirationDate"],
    "provisioned_device_count" => Array(values["ProvisionedDevices"]).length,
    "provisions_all_devices" => values["ProvisionsAllDevices"],
    "provisioned_devices_present" => values.key?("ProvisionedDevices"),
    "developer_certificate_count" => developer_certificate_sha256s.length,
    "developer_certificate_sha256s" => developer_certificate_sha256s,
    "entitlements" => DeployIOSSupport.selected_entitlements(values["Entitlements"])
  }.reject { |_, value| value.nil? }
end

def entitlement_pattern_matches?(pattern, value)
  expression = Regexp.escape(pattern.to_s).gsub("\\*", ".*")
  value.to_s.match?(/\A#{expression}\z/)
end

def entitlement_authorized?(signed, authorized)
  case signed
  when Array
    allowed = Array(authorized)
    signed.all? { |value| allowed.any? { |pattern| entitlement_pattern_matches?(pattern, value) } }
  when String
    Array(authorized).any? { |pattern| entitlement_pattern_matches?(pattern, signed) }
  else
    signed == authorized
  end
end

def profile_channel(profile)
  entitlements = profile.fetch("entitlements")
  return "enterprise" if profile["provisions_all_devices"]
  return "development" if profile["provisioned_devices_present"] && entitlements["get_task_allow"] == true
  return "ad-hoc" if profile["provisioned_devices_present"] && entitlements["get_task_allow"] != true
  return "app-store-connect" unless profile["provisioned_devices_present"]

  "unknown"
end

def inspect_signable(bundle, label, allow_unsigned:, require_bundle_identifier: true)
  info = bundle_info(bundle)
  stdout, stderr, status = DeployIOSSupport.capture("codesign", "--display", "--verbose=4", bundle, allow_failure: true)
  signed = status.success?
  signature_text = "#{stdout}\n#{stderr}"
  linker_signed = signature_text.match?(
    /^CodeDirectory\b[^\r\n]*\bflags=[^\r\n]*\([^\r\n)]*\blinker-signed\b[^\r\n)]*\)/i
  )
  signature = {
    "signed" => signed,
    "kind" => signature_text[/^Signature=(.+)$/i, 1]&.strip,
    "linker_signed" => linker_signed || nil,
    "identifier" => signature_text[/^Identifier=(.+)$/i, 1]&.strip,
    "team_identifier" => signature_text[/^TeamIdentifier=(.+)$/i, 1]&.strip,
    "cdhash" => signature_text[/^CDHash=(.+)$/i, 1]&.strip,
    "timestamp" => signature_text[/^Timestamp=(.+)$/i, 1]&.strip
  }.compact
  entitlements = {}
  unverified_entitlement_keys = []
  warnings = []
  checks = []

  if signed
    entitlement_stdout, entitlement_stderr, entitlement_status = DeployIOSSupport.capture(
      "codesign", "--display", "--entitlements", ":-", bundle,
      allow_failure: true
    )
    if entitlement_status.success?
      all_entitlements = plist_from_command_output(entitlement_stdout, entitlement_stderr)
      entitlements = DeployIOSSupport.selected_entitlements(
        all_entitlements
      )
      unverified_entitlement_keys = all_entitlements.keys.map(&:to_s) - DeployIOSSupport::SUPPORTED_ENTITLEMENT_KEYS
      checks << DeployIOSSupport.check(
        "#{label}: every signed entitlement key has modeled authorization semantics",
        [],
        unverified_entitlement_keys.sort
      )
    else
      warnings << "#{label}: codesign could not read signed entitlements."
    end
    checks << DeployIOSSupport.check("#{label}: signed entitlements are readable", true, entitlement_status.success?) unless allow_unsigned

    unless allow_unsigned
      Dir.mktmpdir("deploy-ios-certificate") do |tmp|
        prefix = File.join(tmp, "certificate")
        _, _, certificate_status = DeployIOSSupport.capture(
          "codesign", "--display", "--extract-certificates=#{prefix}", bundle,
          allow_failure: true
        )
        certificate = "#{prefix}0"
        if certificate_status.success? && File.file?(certificate)
          signature["certificate_sha256"] = Digest::SHA256.file(certificate).hexdigest
        else
          warnings << "#{label}: codesign could not extract the leaf signing certificate."
        end
      end
    end

    unless signature["linker_signed"]
      _, _, verification_status = DeployIOSSupport.capture(
        "codesign", "--verify", "--strict", bundle,
        allow_failure: true
      )
      checks << DeployIOSSupport.check("#{label}: code signature verifies", true, verification_status.success?)
    end
  end

  checks << DeployIOSSupport.check("#{label}: bundle is signed", true, signed) unless allow_unsigned
  bundle_id = info["CFBundleIdentifier"]
  if require_bundle_identifier
    checks << DeployIOSSupport.check(
      "#{label}: bundle identifier is present",
      true,
      bundle_id.is_a?(String) && bundle_id.match?(/\A[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\z/)
    )
  end
  if !allow_unsigned && signed && signature["identifier"] && bundle_id
    checks << DeployIOSSupport.check("#{label}: bundle identifier matches the signature", bundle_id, signature["identifier"])
  end
  signed_team = entitlements["team_identifier"] || signature["team_identifier"]
  if !allow_unsigned && %w[.app .appex].include?(bundle.extname.downcase)
    checks << DeployIOSSupport.check(
      "#{label}: signed application identifier is present",
      true,
      entitlements["application_identifier"].is_a?(String) && !entitlements["application_identifier"].empty?
    )
    checks << DeployIOSSupport.check("#{label}: signing team is present", true, signed_team.is_a?(String) && !signed_team.empty?)
  end
  signed_application_identifier = entitlements["application_identifier"]
  if bundle_id && signed_application_identifier
    _, separator, application_identifier_suffix = signed_application_identifier.partition(".")
    checks << DeployIOSSupport.check(
      "#{label}: signed application identifier suffix matches the bundle",
      bundle_id,
      separator.empty? ? nil : application_identifier_suffix
    )
  end

  profile = provisioning_profile(bundle)
  if profile
    expiration = begin
      Time.parse(profile["expiration_date"].to_s)
    rescue
      nil
    end
    checks << DeployIOSSupport.check("#{label}: embedded profile is unexpired", true, expiration ? expiration > Time.now : false)
    profile_entitlements = profile.fetch("entitlements")
    entitlements.each do |name, signed_value|
      checks << DeployIOSSupport.check(
        "#{label}: profile authorizes signed entitlement #{name}",
        profile_entitlements[name],
        signed_value,
        comparator: ->(authorized, signed) { entitlement_authorized?(signed, authorized) }
      )
    end

    checks << DeployIOSSupport.check(
      "#{label}: profile authorizes the leaf signing certificate",
      true,
      signature["certificate_sha256"] && profile.fetch("developer_certificate_sha256s").include?(signature["certificate_sha256"])
    )
    if signed_team
      checks << DeployIOSSupport.check(
        "#{label}: profile team includes the signing team",
        signed_team,
        profile.fetch("team_identifiers"),
        comparator: ->(expected, authorized) { authorized.include?(expected) }
      )
    end
    if signed_application_identifier
      application_identifier_prefix = signed_application_identifier.partition(".").first
      checks << DeployIOSSupport.check(
        "#{label}: profile permits the application identifier prefix",
        application_identifier_prefix,
        profile.fetch("application_identifier_prefixes"),
        comparator: ->(expected, permitted) { permitted.include?(expected) }
      )
    end
  elsif !allow_unsigned && %w[.app .appex].include?(bundle.extname.downcase)
    checks << DeployIOSSupport.check("#{label}: embedded provisioning profile is present", true, false)
  end

  profile_evidence = profile&.dup
  profile_evidence&.delete("developer_certificate_sha256s")
  evidence = {
    "name" => bundle.basename.to_s,
    "kind" => bundle.extname.delete_prefix("."),
    "bundle_identifier" => bundle_id,
    "marketing_version" => info["CFBundleShortVersionString"],
    "build_number" => info["CFBundleVersion"]&.to_s,
    "signature" => signature,
    "signed_entitlements" => entitlements,
    "unverified_entitlement_keys" => unverified_entitlement_keys.sort,
    "embedded_profile" => profile_evidence
  }.reject { |_, value| value.nil? }
  [evidence, checks, warnings, info]
end

def nested_signables(application)
  patterns = %w[**/*.appex **/*.app **/*.framework **/*.xpc]
  patterns.flat_map { |pattern| Dir.glob(application.join(pattern).to_s) }
    .map { |path| Pathname.new(path) }
    .select { |path| path.directory? && !path.symlink? && path_within?(application, path) }
    .reject { |path| path == application }
    .uniq
    .sort_by(&:to_s)
end

def standalone_dylibs(application)
  Dir.glob(application.join("**/*.dylib").to_s).sort
    .map { |path| Pathname.new(path) }
    .select { |path| safe_binary_file?(application, path) }
end

def safe_bundle_executable_path(bundle, info)
  executable = info["CFBundleExecutable"]
  return nil unless executable.is_a?(String) && !executable.empty?
  return nil if executable.include?("\0") || executable.include?("\\")
  return nil unless executable == File.basename(executable) && !%w[. ..].include?(executable)

  bundle.join(executable).cleanpath
end

def safe_binary_file?(application, path)
  path && !path.symlink? && path_within?(application, path) && path.file?
end

def binary_candidates(application, info, nested_bundles, dylibs)
  candidates = [["main application", safe_bundle_executable_path(application, info)]]
  nested_bundles.each do |bundle|
    relative = bundle.relative_path_from(application).to_s
    executable = safe_bundle_executable_path(bundle, bundle_info(bundle))
    candidates << ["nested #{relative}", executable]
  end
  dylibs.each do |candidate|
    candidates << ["embedded #{candidate.relative_path_from(application)}", candidate]
  end
  candidates.uniq { |label, path| path ? path.to_s : label }
end

def inspect_binaries(application, candidates)
  candidates.each_with_object([]) do |(label, path), binaries|
    next unless safe_binary_file?(application, path)

    stdout, _, status = DeployIOSSupport.capture("lipo", "-archs", path, allow_failure: true)
    next unless status.success?

    binaries << {
      "label" => label,
      "path" => path.relative_path_from(application).to_s,
      "sha256" => Digest::SHA256.file(path).hexdigest,
      "architectures" => stdout.split.uniq.sort
    }
  end
end

def credential_free_signable?(signable)
  signature = signable.fetch("signature")
  signed_team = signable.fetch("signed_entitlements")["team_identifier"] || signature["team_identifier"]
  team_absent = signed_team.nil? || signed_team.empty? || signed_team.to_s.downcase == "not set"

  !signature.fetch("signed") ||
    (signature["kind"].to_s.downcase == "adhoc" && team_absent && signable["embedded_profile"].nil?)
end

def inspect_application(application, artifact, artifact_kind, options)
  info_path = application.join("Info.plist")
  raise DeployIOSSupport::Error, "Application has no Info.plist" unless info_path.file?

  main, checks, warnings, info = inspect_signable(application, "main application", allow_unsigned: options[:allow_unsigned])
  nested_bundles = nested_signables(application)
  nested = nested_bundles.map do |bundle|
    relative = bundle.relative_path_from(application).to_s
    evidence, bundle_checks, bundle_warnings, = inspect_signable(
      bundle,
      "nested #{relative}",
      allow_unsigned: options[:allow_unsigned]
    )
    evidence["path"] = relative
    checks.concat(bundle_checks)
    warnings.concat(bundle_warnings)
    evidence
  end
  dylibs = standalone_dylibs(application)
  dylibs.each do |dylib|
    relative = dylib.relative_path_from(application).to_s
    evidence, dylib_checks, dylib_warnings, = inspect_signable(
      dylib,
      "embedded #{relative}",
      allow_unsigned: options[:allow_unsigned],
      require_bundle_identifier: false
    )
    evidence["path"] = relative
    checks.concat(dylib_checks)
    warnings.concat(dylib_warnings)
    nested << evidence
  end
  all_signables = [main, *nested]
  all_signables.each do |signable|
    signable.fetch("signature")["credential_free"] = credential_free_signable?(signable)
  end

  signature = main.fetch("signature")
  signed_entitlements = main.fetch("signed_entitlements")
  profile = main["embedded_profile"]
  bundle_id = main["bundle_identifier"]
  version = main["marketing_version"]
  build_number = main["build_number"]
  embedded_revision = %w[SourceRevision SOURCE_REVISION GitCommit GIT_COMMIT].map { |key| info[key] }.compact.first
  origins = origins_in(info).uniq.sort
  source = options[:source_root] ? DeployIOSSupport.git_evidence(Pathname.new(options[:source_root]).expand_path) : {"provided" => false}
  platform = info["DTPlatformName"]
  executable_name = info["CFBundleExecutable"]
  candidates = binary_candidates(application, info, nested_bundles, dylibs)
  binaries = inspect_binaries(application, candidates)
  main_binary = binaries.find { |binary| binary["label"] == "main application" }
  executable_sha256 = main_binary&.fetch("sha256", nil)
  architectures = main_binary ? main_binary.fetch("architectures") : []

  artifact_sha256 = if artifact.file?
    Digest::SHA256.file(artifact).hexdigest
  else
    DeployIOSSupport.directory_manifest_sha256(artifact)
  end

  checks << DeployIOSSupport.check(
    "main application marketing version is present and numeric",
    true,
    version.is_a?(String) && version.match?(/\A\d+(?:\.\d+){0,2}\z/)
  )
  checks << DeployIOSSupport.check(
    "main application build number is present and positive",
    true,
    build_number.is_a?(String) && build_number.match?(/\A\d+(?:\.\d+){0,2}\z/) && build_number.split(".").first.to_i.positive?
  )
  candidates.each do |label, path|
    relative = safe_binary_file?(application, path) ? path.relative_path_from(application).to_s : nil
    binary = binaries.find { |evidence| evidence["label"] == label && evidence["path"] == relative }
    checks << DeployIOSSupport.check("#{label}: executable is present and contained in the app", true, !relative.nil?)
    checks << DeployIOSSupport.check("#{label}: architectures are readable", true, binary && !binary.fetch("architectures").empty?)
    options[:architectures].each do |architecture|
      checks << DeployIOSSupport.check(
        "#{label}: architecture #{architecture}",
        true,
        binary ? binary.fetch("architectures").include?(architecture) : false
      )
    end
  end

  if signature["signed"] && !signature["linker_signed"]
    _, _, deep_status = DeployIOSSupport.capture(
      "codesign", "--verify", "--deep", "--strict", application,
      allow_failure: true
    )
    checks << DeployIOSSupport.check("complete application signature graph verifies", true, deep_status.success?)
  end
  checks << DeployIOSSupport.check("bundle identifier", options[:bundle_id], bundle_id) if options[:bundle_id]
  checks << DeployIOSSupport.check("Apple platform", options[:platform], platform) if options[:platform]
  if options[:expect_unsigned]
    all_signables.each do |signable|
      label = if signable.equal?(main)
        "main application"
      elsif signable.fetch("kind") == "dylib"
        "embedded #{signable.fetch("path")}"
      else
        "nested #{signable.fetch("path")}"
      end
      checks << DeployIOSSupport.check(
        "#{label} has no Apple signing identity or profile",
        true,
        signable.dig("signature", "credential_free")
      )
    end
  end
  checks << DeployIOSSupport.check("marketing version", options[:version], version) if options[:version]
  checks << DeployIOSSupport.check("build number", options[:build_number], build_number) if options[:build_number]
  checks << DeployIOSSupport.check("artifact SHA-256", options[:artifact_sha256], artifact_sha256) if options[:artifact_sha256]
  if options[:certificate_sha256]
    checks << DeployIOSSupport.check("leaf certificate SHA-256", options[:certificate_sha256], signature["certificate_sha256"])
  end

  if options[:channel]
    all_signables.select { |signable| %w[app appex].include?(signable.fetch("kind")) }.each do |signable|
      signable_profile = signable["embedded_profile"]
      checks << DeployIOSSupport.check(
        "#{signable.fetch("name")}: provisioning channel",
        options[:channel],
        signable_profile ? profile_channel(signable_profile) : "missing-profile"
      )
      signed_aps = signable.dig("signed_entitlements", "aps_environment")
      if signed_aps
        expected_aps = (options[:channel] == "development") ? "development" : "production"
        checks << DeployIOSSupport.check("#{signable.fetch("name")}: APNs environment for channel", expected_aps, signed_aps)
      end
    end
  end
  if options[:team_id]
    all_signables.select { |signable| %w[app appex xpc].include?(signable.fetch("kind")) }.each do |signable|
      signable_signature = signable.fetch("signature")
      entitlements = signable.fetch("signed_entitlements")
      signable_profile = signable["embedded_profile"]
      team_evidence = [
        signable_signature["team_identifier"],
        entitlements["team_identifier"],
        *Array(signable_profile&.fetch("team_identifiers", nil))
      ].compact.uniq
      checks << DeployIOSSupport.check(
        "#{signable.fetch("name")}: Apple team identifier",
        options[:team_id],
        team_evidence,
        comparator: ->(expected, actual) { actual.include?(expected) }
      )
    end
  end
  nested_ids = nested.map { |signable| signable["bundle_identifier"] }.compact
  options[:nested_bundle_ids].each do |expected|
    checks << DeployIOSSupport.check(
      "nested bundle identifier #{expected}",
      expected,
      nested_ids,
      comparator: ->(value, actual) { actual.include?(value) }
    )
  end
  if options[:aps_environment]
    checks << DeployIOSSupport.check("APNs environment", options[:aps_environment], signed_entitlements["aps_environment"])
  end
  options[:associated_domains].each do |domain|
    checks << DeployIOSSupport.check(
      "Associated Domain #{domain}",
      domain,
      Array(signed_entitlements["associated_domains"]),
      comparator: ->(expected, actual) { actual.include?(expected) }
    )
  end
  checks << DeployIOSSupport.check("profile UUID", options[:profile_uuid], profile&.fetch("uuid", nil)) if options[:profile_uuid]
  if options[:rails_origin]
    checks << DeployIOSSupport.check(
      "Rails origin",
      normalized_origin(options[:rails_origin]),
      origins,
      comparator: ->(expected, actual) { actual.include?(expected) }
    )
  end

  if options[:source_root]
    checks << DeployIOSSupport.check("source checkout is clean", false, source["dirty"]) if options[:expect_clean_source]
    checks << DeployIOSSupport.check("source revision", options[:source_sha], source["revision"]) if options[:source_sha]
  elsif options[:expect_clean_source] || options[:source_sha]
    raise DeployIOSSupport::Error, "--source-root is required for source checks"
  end
  if options[:source_sha]
    checks << DeployIOSSupport.check("embedded source revision", options[:source_sha], embedded_revision)
  end
  if options[:source_root] && !options[:source_sha] && !embedded_revision
    warnings << "The artifact does not embed its source revision; the reported checkout is context, not proof of the artifact's source."
  elsif options[:source_root] && embedded_revision != source["revision"]
    warnings << "The artifact's embedded source revision differs from the reported checkout."
  end

  {
    "schema_version" => 1,
    "kind" => "hotwire_native_ios_artifact_inspection",
    "artifact" => {
      "name" => artifact.basename.to_s,
      "type" => artifact_kind,
      "sha256" => artifact_sha256,
      "digest_kind" => artifact.file? ? "file_sha256" : "directory_manifest_sha256"
    },
    "application" => {
      "bundle_identifier" => bundle_id,
      "marketing_version" => version,
      "build_number" => build_number,
      "minimum_os_version" => info["MinimumOSVersion"],
      "platform" => platform,
      "executable" => executable_name,
      "executable_sha256" => executable_sha256,
      "architectures" => architectures,
      "embedded_binaries" => binaries,
      "embedded_source_revision" => embedded_revision,
      "rails_origins" => origins
    }.reject { |_, value| value.nil? },
    "signature" => signature,
    "signed_entitlements" => signed_entitlements,
    "unverified_entitlement_keys" => main.fetch("unverified_entitlement_keys"),
    "embedded_profile" => profile,
    "nested_signables" => nested,
    "source" => source,
    "warnings" => warnings,
    "checks" => checks
  }
end

begin
  with_application(artifact, options[:max_extracted_bytes]) do |application, artifact_kind|
    report = inspect_application(application, artifact, artifact_kind, options)
    DeployIOSSupport.result_exit!(report, json: options[:json])
  end
rescue DeployIOSSupport::Error => error
  warn DeployIOSSupport.redact_error(error, [artifact, options[:source_root]])
  exit 1
end
