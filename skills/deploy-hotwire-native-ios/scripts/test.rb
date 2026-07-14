#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

SKILL_ROOT = File.expand_path("..", __dir__)
RUBY = RbConfig.ruby
AUDITOR = File.join(SKILL_ROOT, "scripts/audit_project.rb")
INSPECTOR = File.join(SKILL_ROOT, "scripts/inspect_artifact.rb")

def run_command(environment = {}, *command, expect_exit: 0)
  stdout, stderr, status = Open3.capture3(environment, *command)
  return [stdout, stderr] if status.exitstatus == expect_exit

  warn "Command failed: #{command.first} (expected #{expect_exit}, got #{status.exitstatus})"
  warn stdout
  warn stderr
  raise "Unexpected command result"
end

def write(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
end

def info_plist(source_revision: nil)
  revision_entry = if source_revision
    "<key>SourceRevision</key><string>#{source_revision}</string>"
  end

  <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>com.firstdraft.Example</string>
      <key>CFBundleShortVersionString</key><string>1.2.3</string>
      <key>CFBundleVersion</key><string>42</string>
      <key>MinimumOSVersion</key><string>16.0</string>
      <key>RailsOrigin</key><string>https://example.test/posts?ignored=true</string>
      #{revision_entry}
    </dict></plist>
  PLIST
end

def entitlements_plist
  <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0"><dict>
      <key>application-identifier</key><string>LEGACY1234.com.firstdraft.Example</string>
      <key>com.apple.developer.team-identifier</key><string>ABCDE12345</string>
      <key>aps-environment</key><string>production</string>
      <key>com.apple.developer.associated-domains</key>
      <array><string>applinks:example.test</string></array>
      <key>keychain-access-groups</key>
      <array><string>LEGACY1234.com.firstdraft.Example</string></array>
      <key>com.apple.security.application-groups</key>
      <array><string>group.com.firstdraft.Example</string></array>
      <key>get-task-allow</key><false/>
    </dict></plist>
  PLIST
end

def profile_plist(
  certificate: "fixture-leaf-certificate",
  associated_domain: "*",
  application_group: "group.com.firstdraft.*",
  application_identifier_prefix: "LEGACY1234",
  provisioned_devices: true
)
  device_entry = if provisioned_devices
    "<key>ProvisionedDevices</key><array><string>device-id-is-not-reported</string></array>"
  end

  <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0"><dict>
      <key>UUID</key><string>11111111-2222-3333-4444-555555555555</string>
      <key>TeamIdentifier</key><array><string>ABCDE12345</string></array>
      <key>ApplicationIdentifierPrefix</key><array><string>#{application_identifier_prefix}</string></array>
      <key>CreationDate</key><date>2026-01-01T00:00:00Z</date>
      <key>ExpirationDate</key><date>2099-01-01T00:00:00Z</date>
      #{device_entry}
      <key>DeveloperCertificates</key><array><data>#{Base64.strict_encode64(certificate)}</data></array>
      <key>Entitlements</key><dict>
        <key>application-identifier</key><string>#{application_identifier_prefix}.*</string>
        <key>com.apple.developer.team-identifier</key><string>ABCDE12345</string>
        <key>aps-environment</key><string>production</string>
        <key>com.apple.developer.associated-domains</key>
        <array><string>#{associated_domain}</string></array>
        <key>keychain-access-groups</key>
        <array><string>#{application_identifier_prefix}.*</string></array>
        <key>com.apple.security.application-groups</key>
        <array><string>#{application_group}</string></array>
        <key>get-task-allow</key><false/>
      </dict>
    </dict></plist>
  PLIST
end

Dir.mktmpdir("deploy-hotwire-native-ios-test") do |tmp|
  project = File.join(tmp, "project")
  FileUtils.mkdir_p(project)
  run_command({}, "/usr/bin/git", "init", "-q", project)
  run_command({}, "/usr/bin/git", "-C", project, "config", "user.email", "tests@example.test")
  run_command({}, "/usr/bin/git", "-C", project, "config", "user.name", "Skill Tests")

  write(File.join(project, "ios/Example.xcodeproj/project.pbxproj"), <<~PBX)
    /* Begin XCBuildConfiguration section */
      ABC /* Debug */ = {
        isa = XCBuildConfiguration;
        PRODUCT_BUNDLE_IDENTIFIER = com.firstdraft.Example;
        DEVELOPMENT_TEAM = ABCDE12345;
        IPHONEOS_DEPLOYMENT_TARGET = 16.0;
        name = Debug;
      };
      DEF /* Release */ = {
        isa = XCBuildConfiguration;
        PRODUCT_BUNDLE_IDENTIFIER = com.firstdraft.Example;
        DEVELOPMENT_TEAM = ABCDE12345;
        IPHONEOS_DEPLOYMENT_TARGET = 16.0;
        name = Release;
      };
    /* End XCBuildConfiguration section */
    name = ThisIsNotABuildConfiguration;
  PBX
  write(File.join(project, "ios/Example.xcodeproj/xcshareddata/xcschemes/Example.xcscheme"), <<~XML)
    <Scheme>
      <LaunchAction>
        <EnvironmentVariables>
          <EnvironmentVariable key="APP_ROOT_URL" value="http://localhost:3000" isEnabled="YES" />
          <EnvironmentVariable key="PRIVATE_VALUE" value="must-not-appear" isEnabled="YES" />
        </EnvironmentVariables>
      </LaunchAction>
    </Scheme>
  XML
  write(File.join(project, "ios/Example.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"), "{\"pins\":[],\"version\":2}\n")
  write(File.join(project, "ios/Config/Production.xcconfig"), "RAILS_ORIGIN = https://example.test\n")
  write(File.join(project, "ios/Example/Example.entitlements"), entitlements_plist)
  write(File.join(project, "ios/Example/AppConfiguration.swift"), "let origin = URL(string: \"https://example.test\")!\n")
  write(File.join(project, "ios/ExampleTests/OriginTests.swift"), "let maliciousFixture = \"https://wrong.example.test\"\n")
  write(File.join(project, ".github/workflows/ios.yml"), <<~YAML)
    on: workflow_dispatch
    jobs:
      build:
        runs-on: macos-latest
        steps:
          - run: bundle exec fastlane testflight
            env:
              KEY: ${{ secrets.SIGNING_KEY }}
  YAML
  write(File.join(project, "Gemfile"), "source \"https://rubygems.org\"\ngem \"fastlane\"\n")
  write(File.join(project, "Gemfile.lock"), "GEM\n  specs:\n    fastlane (2.0.0)\n")
  write(File.join(project, "fastlane/Fastfile"), "lane :testflight do\nend\n")

  run_command({}, "/usr/bin/git", "-C", project, "add", ".")
  run_command({}, "/usr/bin/git", "-C", project, "commit", "-qm", "Fixture")
  revision, = run_command({}, "/usr/bin/git", "-C", project, "rev-parse", "HEAD")
  revision = revision.strip

  stdout, = run_command(
    {}, RUBY, AUDITOR,
    "--root", project,
    "--json",
    "--expect-clean-source",
    "--expect-bundle-id", "com.firstdraft.Example",
    "--expect-team-id", "ABCDE12345",
    "--expect-rails-origin", "https://example.test"
  )
  audit = JSON.parse(stdout)
  raise "Project source revision was not captured" unless audit.dig("source", "revision") == revision
  raise "Shared scheme was not detected" unless audit.dig("xcode", "shared_schemes").include?("ios/Example.xcodeproj/xcshareddata/xcschemes/Example.xcscheme")
  raise "Enabled localhost scheme override was not reported" unless audit.fetch("warnings").any? { |warning| warning.include?("physical iPhone") }
  raise "APNs entitlement was not detected" unless audit.dig("settings", "entitlements", 0, "values", "aps_environment") == "production"
  raise "Project entitlement limitation was not reported" unless audit.fetch("warnings").any? { |warning| warning.include?("project request only") }
  raise "Test fixtures must not be reported as release origins" if audit.dig("settings", "rails_origins").any? { |item| item.fetch("file").include?("Tests/") }
  raise "Workflow secret values or names should not be emitted" if stdout.include?("SIGNING_KEY")
  raise "Scheme environment values must be redacted" if stdout.include?("must-not-appear")
  raise "Audit checks failed" unless audit.fetch("checks").all? { |check| check["passed"] }

  write(File.join(project, "uncommitted.txt"), "dirty\n")
  stdout, = run_command({}, RUBY, AUDITOR, "--root", project, "--json", "--expect-clean-source", expect_exit: 2)
  dirty_audit = JSON.parse(stdout)
  raise "Dirty source was not reported" unless dirty_audit.dig("source", "dirty")
  FileUtils.rm_f(File.join(project, "uncommitted.txt"))

  private_key_marker = ["-----BEGIN", "ENCRYPTED PRIVATE KEY-----"].join(" ")
  write(File.join(project, "credentials.bin"), "#{private_key_marker}\n#{"A" * 64}\n")
  stdout, = run_command({}, RUBY, AUDITOR, "--root", project, "--json", expect_exit: 2)
  secret_audit = JSON.parse(stdout)
  unless secret_audit.dig("sensitive_material_scan", "candidate_types", "private_key_content") == 1
    raise "Private-key content under an arbitrary filename was not detected"
  end
  FileUtils.rm_f(File.join(project, "credentials.bin"))

  fake_bin = File.join(tmp, "fake-bin")
  FileUtils.mkdir_p(fake_bin)
  fake_codesign = File.join(fake_bin, "codesign")
  fake_security = File.join(fake_bin, "security")
  write(fake_codesign, <<~'RUBY')
    #!/usr/bin/env ruby
    arguments = ARGV
    if (argument = arguments.find { |value| value.start_with?("--extract-certificates=") })
      File.binwrite("#{argument.split("=", 2).last}0", "fixture-leaf-certificate")
    elsif arguments.include?("--entitlements")
      entitlements = ENV.fetch("FIXTURE_ENTITLEMENTS")
      if arguments.last.end_with?("Share.appex")
        entitlements = entitlements.gsub("com.firstdraft.Example", "com.firstdraft.Example.Share")
      end
      puts entitlements
    else
      identifier = arguments.last.end_with?("Share.appex") ? "com.firstdraft.Example.Share" : "com.firstdraft.Example"
      warn "Executable=/private/path/that/must/not/appear"
      warn "Identifier=#{identifier}"
      warn "TeamIdentifier=ABCDE12345"
      warn "Authority=Private Person Must Not Appear"
      warn "CDHash=0123456789abcdef"
      warn "Timestamp=Jul 14, 2026"
    end
  RUBY
  write(fake_security, <<~RUBY)
    #!/usr/bin/env ruby
    puts ENV.fetch("FIXTURE_PROFILE")
  RUBY
  FileUtils.chmod(0o755, [fake_codesign, fake_security])

  application = File.join(tmp, "Example.app")
  FileUtils.mkdir_p(application)
  write(File.join(application, "Info.plist"), info_plist(source_revision: revision))
  write(File.join(application, "embedded.mobileprovision"), "opaque-profile-fixture")
  write(File.join(application, "Example"), "binary-fixture")
  extension = File.join(application, "PlugIns/Share.appex")
  FileUtils.mkdir_p(extension)
  write(File.join(extension, "Info.plist"), info_plist(source_revision: revision).sub("com.firstdraft.Example", "com.firstdraft.Example.Share"))
  write(File.join(extension, "embedded.mobileprovision"), "opaque-extension-profile-fixture")
  write(File.join(extension, "Share"), "extension-binary-fixture")

  environment = {
    "DEPLOY_IOS_TOOL_CODESIGN" => fake_codesign,
    "DEPLOY_IOS_TOOL_SECURITY" => fake_security,
    "FIXTURE_ENTITLEMENTS" => entitlements_plist,
    "FIXTURE_PROFILE" => profile_plist
  }
  certificate_sha256 = Digest::SHA256.hexdigest("fixture-leaf-certificate")

  stdout, = run_command(
    environment, RUBY, INSPECTOR,
    "--json",
    "--source-root", project,
    "--expect-clean-source",
    "--expect-source-sha", revision,
    "--expect-certificate-sha256", certificate_sha256,
    "--expect-bundle-id", "com.firstdraft.Example",
    "--expect-nested-bundle-id", "com.firstdraft.Example.Share",
    "--expect-team-id", "ABCDE12345",
    "--expect-version", "1.2.3",
    "--expect-build-number", "42",
    "--expect-channel", "ad-hoc",
    "--expect-aps-environment", "production",
    "--expect-associated-domain", "applinks:example.test",
    "--expect-profile-uuid", "11111111-2222-3333-4444-555555555555",
    "--expect-rails-origin", "https://example.test",
    application
  )
  inspection = JSON.parse(stdout)
  raise "Artifact checks failed" unless inspection.fetch("checks").all? { |check| check["passed"] }
  raise "Embedded source revision was not captured" unless inspection.dig("application", "embedded_source_revision") == revision
  raise "Nested extension was not inspected" unless inspection.dig("nested_signables", 0, "bundle_identifier") == "com.firstdraft.Example.Share"
  raise "Certificate fingerprint was not captured" unless inspection.dig("signature", "certificate_sha256") == certificate_sha256
  raise "Profile device identifiers must not be emitted" if stdout.include?("device-id-is-not-reported")
  raise "Signing identity names must not be emitted" if stdout.include?("Private Person Must Not Appear")
  raise "Absolute command output paths must not be emitted" if stdout.include?("/private/path")

  stdout, = run_command(
    environment, RUBY, INSPECTOR,
    "--json", "--expect-build-number", "999", application,
    expect_exit: 2
  )
  mismatch = JSON.parse(stdout)
  raise "Expected mismatch did not fail" if mismatch.fetch("checks").all? { |check| check["passed"] }

  stdout, = run_command(
    environment.merge("FIXTURE_PROFILE" => profile_plist(certificate: "unauthorized-certificate")),
    RUBY, INSPECTOR, "--json", application,
    expect_exit: 2
  )
  unauthorized_certificate = JSON.parse(stdout)
  unless unauthorized_certificate.fetch("checks").any? { |check| check["label"].include?("leaf signing certificate") && !check["passed"] }
    raise "Unauthorized signing certificate was not rejected"
  end

  stdout, = run_command(
    environment.merge("FIXTURE_PROFILE" => profile_plist(associated_domain: "applinks:other.test")),
    RUBY, INSPECTOR, "--json", application,
    expect_exit: 2
  )
  unauthorized_domain = JSON.parse(stdout)
  unless unauthorized_domain.fetch("checks").any? { |check| check["label"].include?("associated_domains") && !check["passed"] }
    raise "Unauthorized Associated Domain was not rejected"
  end

  stdout, = run_command(
    environment.merge("FIXTURE_PROFILE" => profile_plist(application_group: "group.example.other")),
    RUBY, INSPECTOR, "--json", application,
    expect_exit: 2
  )
  unauthorized_group = JSON.parse(stdout)
  unless unauthorized_group.fetch("checks").any? { |check| check["label"].include?("application_groups") && !check["passed"] }
    raise "Unauthorized application group was not rejected"
  end

  stdout, = run_command(
    environment.merge("FIXTURE_PROFILE" => profile_plist(application_identifier_prefix: "OTHER12345")),
    RUBY, INSPECTOR, "--json", application,
    expect_exit: 2
  )
  unauthorized_prefix = JSON.parse(stdout)
  unless unauthorized_prefix.fetch("checks").any? { |check| check["label"].include?("application identifier prefix") && !check["passed"] }
    raise "Unauthorized application identifier prefix was not rejected"
  end

  unmodeled_entitlements = entitlements_plist.sub(
    "</dict></plist>",
    "<key>com.apple.developer.healthkit</key><true/></dict></plist>"
  )
  stdout, = run_command(
    environment.merge("FIXTURE_ENTITLEMENTS" => unmodeled_entitlements),
    RUBY, INSPECTOR, "--json", application,
    expect_exit: 2
  )
  unmodeled = JSON.parse(stdout)
  unless unmodeled.fetch("unverified_entitlement_keys").include?("com.apple.developer.healthkit")
    raise "Unmodeled signed entitlement key was not reported"
  end
  unless unmodeled.fetch("checks").any? { |check| check["label"].include?("modeled authorization semantics") && !check["passed"] }
    raise "Unmodeled signed entitlement was not rejected"
  end

  stdout, = run_command(environment, RUBY, INSPECTOR, "--json", "--expect-channel", "development", application, expect_exit: 2)
  wrong_channel = JSON.parse(stdout)
  unless wrong_channel.fetch("checks").any? { |check| check["label"].include?("provisioning channel") && !check["passed"] }
    raise "Wrong provisioning channel was not rejected"
  end

  stdout, = run_command(
    environment.merge("FIXTURE_PROFILE" => profile_plist(provisioned_devices: false)),
    RUBY, INSPECTOR, "--json", "--expect-channel", "app-store-connect", application
  )
  app_store_channel = JSON.parse(stdout)
  unless app_store_channel.fetch("checks").all? { |check| check["passed"] }
    raise "App Store Connect provisioning channel was not recognized"
  end

  missing_profile_application = File.join(tmp, "MissingProfile.app")
  FileUtils.cp_r(application, missing_profile_application)
  FileUtils.rm_f(File.join(missing_profile_application, "embedded.mobileprovision"))
  stdout, = run_command(environment, RUBY, INSPECTOR, "--json", missing_profile_application, expect_exit: 2)
  missing_profile = JSON.parse(stdout)
  unless missing_profile.fetch("checks").any? { |check| check["label"].include?("embedded provisioning profile") && !check["passed"] }
    raise "Missing provisioning profile was not rejected"
  end

  missing_revision_application = File.join(tmp, "MissingRevision.app")
  FileUtils.cp_r(application, missing_revision_application)
  write(File.join(missing_revision_application, "Info.plist"), info_plist)
  stdout, = run_command(
    environment, RUBY, INSPECTOR,
    "--json", "--source-root", project, "--expect-source-sha", revision,
    missing_revision_application,
    expect_exit: 2
  )
  missing_revision = JSON.parse(stdout)
  unless missing_revision.fetch("checks").any? { |check| check["label"] == "embedded source revision" && !check["passed"] }
    raise "Missing embedded source revision was not rejected"
  end

  missing_metadata_application = File.join(tmp, "MissingMetadata.app")
  FileUtils.cp_r(application, missing_metadata_application)
  metadata = File.read(File.join(missing_metadata_application, "Info.plist"))
  metadata.sub!(%r{\s*<key>CFBundleVersion</key><string>[^<]+</string>}, "")
  write(File.join(missing_metadata_application, "Info.plist"), metadata)
  stdout, = run_command(environment, RUBY, INSPECTOR, "--json", missing_metadata_application, expect_exit: 2)
  missing_metadata = JSON.parse(stdout)
  unless missing_metadata.fetch("checks").any? { |check| check["label"].include?("build number") && !check["passed"] }
    raise "Missing build number was not rejected"
  end

  archive = File.join(tmp, "Example.xcarchive")
  FileUtils.mkdir_p(File.join(archive, "Products/Applications"))
  FileUtils.cp_r(application, File.join(archive, "Products/Applications/Example.app"))
  stdout, = run_command(environment, RUBY, INSPECTOR, "--json", archive)
  raise "xcarchive was not inspected" unless JSON.parse(stdout).dig("artifact", "type") == "xcarchive"

  ipa_tree = File.join(tmp, "ipa-tree")
  FileUtils.mkdir_p(File.join(ipa_tree, "Payload"))
  FileUtils.cp_r(application, File.join(ipa_tree, "Payload/Example.app"))
  ipa = File.join(tmp, "Example.ipa")
  run_command({}, "/usr/bin/ditto", "-c", "-k", "--keepParent", File.join(ipa_tree, "Payload"), ipa)
  stdout, = run_command(environment, RUBY, INSPECTOR, "--json", ipa)
  raise "IPA was not inspected" unless JSON.parse(stdout).dig("artifact", "type") == "ipa"

  unsafe_zipinfo = File.join(fake_bin, "unsafe-zipinfo")
  write(unsafe_zipinfo, <<~RUBY)
    #!/usr/bin/env ruby
    puts "../escape" if ARGV.first == "-1"
  RUBY
  FileUtils.chmod(0o755, unsafe_zipinfo)
  unsafe_ipa = File.join(tmp, "Unsafe.ipa")
  write(unsafe_ipa, "not-a-real-zip")
  _, stderr = run_command(
    environment.merge("DEPLOY_IOS_TOOL_ZIPINFO" => unsafe_zipinfo),
    RUBY, INSPECTOR, "--json", unsafe_ipa,
    expect_exit: 1
  )
  raise "Unsafe IPA path was not rejected" unless stderr.include?("unsafe archive path")
  raise "Failure output leaked the temporary root" if stderr.include?(tmp)
end

puts "All deploy-hotwire-native-ios verification-tool tests passed."
