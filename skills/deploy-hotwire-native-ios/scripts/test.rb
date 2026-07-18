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

def info_plist(
  source_revision: nil,
  platform: "iphoneos",
  bundle_id: "com.example.HotwireApp",
  executable: "Example"
)
  revision_entry = if source_revision
    "<key>SourceRevision</key><string>#{source_revision}</string>"
  end

  <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>#{bundle_id}</string>
      <key>CFBundleExecutable</key><string>#{executable}</string>
      <key>CFBundleShortVersionString</key><string>1.2.3</string>
      <key>CFBundleVersion</key><string>42</string>
      <key>MinimumOSVersion</key><string>16.0</string>
      <key>DTPlatformName</key><string>#{platform}</string>
      <key>RailsOrigin</key><string>https://example.test</string>
      #{revision_entry}
    </dict></plist>
  PLIST
end

def entitlements_plist
  <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0"><dict>
      <key>application-identifier</key><string>LEGACY1234.com.example.HotwireApp</string>
      <key>com.apple.developer.team-identifier</key><string>ABCDE12345</string>
      <key>aps-environment</key><string>production</string>
      <key>com.apple.developer.associated-domains</key>
      <array><string>applinks:example.test</string></array>
      <key>keychain-access-groups</key>
      <array><string>LEGACY1234.com.example.HotwireApp</string></array>
      <key>com.apple.security.application-groups</key>
      <array><string>group.com.example.HotwireApp</string></array>
      <key>get-task-allow</key><false/>
    </dict></plist>
  PLIST
end

def profile_plist(
  certificate: "fixture-leaf-certificate",
  associated_domain: "*",
  application_group: "group.com.example.*",
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
        PRODUCT_BUNDLE_IDENTIFIER = com.example.HotwireApp;
        DEVELOPMENT_TEAM = ABCDE12345;
        IPHONEOS_DEPLOYMENT_TARGET = 16.0;
        name = Debug;
      };
      DEF /* Release */ = {
        isa = XCBuildConfiguration;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.HotwireApp;
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
    "--expect-bundle-id", "com.example.HotwireApp",
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
  fake_lipo = File.join(fake_bin, "lipo")
  write(fake_codesign, <<~'RUBY')
    #!/usr/bin/env ruby
    arguments = ARGV
    identity_override =
      (ENV["FIXTURE_NESTED_IDENTITY"] == "1" && arguments.last.include?("Preview.framework")) ||
      (ENV["FIXTURE_DYLIB_IDENTITY"] == "1" && arguments.last.end_with?("Support.dylib"))
    if ENV["FIXTURE_INVALID_NESTED_SIGNATURE"] == "1" && arguments.include?("--verify") && arguments.last.include?("Preview.framework")
      exit 1
    end
    exit 1 if ENV["FIXTURE_LINKER_SPOOF"] == "1" && arguments.include?("--verify")
    exit 1 if ENV["FIXTURE_LINKER_SIGNED"] == "1" && arguments.include?("--verify")
    exit 1 if ENV["FIXTURE_UNSIGNED"] == "1" && !identity_override

    if [ENV["FIXTURE_ADHOC"], ENV["FIXTURE_LINKER_SIGNED"], ENV["FIXTURE_LINKER_SPOOF"]].include?("1") && !identity_override
      warn "Executable=/private/tmp/linker-signed.app/Example" if ENV["FIXTURE_LINKER_SPOOF"] == "1"
      warn "Identifier=com.example.HotwireApp"
      warn "CodeDirectory flags=0x20002(adhoc,linker-signed)" if ENV["FIXTURE_LINKER_SIGNED"] == "1"
      warn "Signature=adhoc"
      warn "TeamIdentifier=not set"
    elsif (argument = arguments.find { |value| value.start_with?("--extract-certificates=") })
      File.binwrite("#{argument.split("=", 2).last}0", "fixture-leaf-certificate")
    elsif arguments.include?("--entitlements")
      entitlements = ENV.fetch("FIXTURE_ENTITLEMENTS")
      if arguments.last.end_with?("Share.appex")
        entitlements = entitlements.gsub("com.example.HotwireApp", "com.example.HotwireApp.Share")
      end
      puts entitlements
    else
      identifier = arguments.last.end_with?("Share.appex") ? "com.example.HotwireApp.Share" : "com.example.HotwireApp"
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
  write(fake_lipo, <<~'RUBY')
    #!/usr/bin/env ruby
    architectures = if ARGV.last.include?("Preview.framework")
      ENV.fetch("FIXTURE_FRAMEWORK_ARCHITECTURES", ENV.fetch("FIXTURE_ARCHITECTURES", "arm64 x86_64"))
    elsif ARGV.last.end_with?("Support.dylib")
      ENV.fetch("FIXTURE_DYLIB_ARCHITECTURES", ENV.fetch("FIXTURE_ARCHITECTURES", "arm64 x86_64"))
    else
      ENV.fetch("FIXTURE_ARCHITECTURES", "arm64 x86_64")
    end
    puts architectures
  RUBY
  FileUtils.chmod(0o755, [fake_codesign, fake_security, fake_lipo])

  application = File.join(tmp, "Example.app")
  FileUtils.mkdir_p(application)
  write(File.join(application, "Info.plist"), info_plist(source_revision: revision))
  write(File.join(application, "embedded.mobileprovision"), "opaque-profile-fixture")
  write(File.join(application, "Example"), "binary-fixture")
  extension = File.join(application, "PlugIns/Share.appex")
  FileUtils.mkdir_p(extension)
  write(
    File.join(extension, "Info.plist"),
    info_plist(
      source_revision: revision,
      bundle_id: "com.example.HotwireApp.Share",
      executable: "Share"
    )
  )
  write(File.join(extension, "embedded.mobileprovision"), "opaque-extension-profile-fixture")
  write(File.join(extension, "Share"), "extension-binary-fixture")

  environment = {
    "DEPLOY_IOS_TOOL_CODESIGN" => fake_codesign,
    "DEPLOY_IOS_TOOL_SECURITY" => fake_security,
    "DEPLOY_IOS_TOOL_LIPO" => fake_lipo,
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
    "--expect-bundle-id", "com.example.HotwireApp",
    "--expect-nested-bundle-id", "com.example.HotwireApp.Share",
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
  raise "Nested extension was not inspected" unless inspection.dig("nested_signables", 0, "bundle_identifier") == "com.example.HotwireApp.Share"
  raise "Certificate fingerprint was not captured" unless inspection.dig("signature", "certificate_sha256") == certificate_sha256
  raise "Profile device identifiers must not be emitted" if stdout.include?("device-id-is-not-reported")
  raise "Signing identity names must not be emitted" if stdout.include?("Private Person Must Not Appear")
  raise "Absolute command output paths must not be emitted" if stdout.include?("/private/path")

  _, stderr = run_command(
    environment, RUBY, INSPECTOR,
    "--expect-rails-origin", "https://example.test/not-an-origin", application,
    expect_exit: 1
  )
  unless stderr.include?("absolute HTTP(S) host root")
    raise "A non-root expected Rails URL was not rejected"
  end

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

  simulator_application = File.join(tmp, "SimulatorExample.app")
  FileUtils.mkdir_p(simulator_application)
  write(
    File.join(simulator_application, "Info.plist"),
    info_plist(source_revision: revision, platform: "iphonesimulator")
  )
  write(File.join(simulator_application, "Example"), "universal-simulator-binary-fixture")
  simulator_framework = File.join(simulator_application, "Frameworks/Preview.framework")
  FileUtils.mkdir_p(simulator_framework)
  write(
    File.join(simulator_framework, "Info.plist"),
    info_plist(
      source_revision: revision,
      platform: "iphonesimulator",
      bundle_id: "com.example.HotwireApp.Preview",
      executable: "Preview"
    )
  )
  write(File.join(simulator_framework, "Preview"), "universal-framework-binary-fixture")
  simulator_dylib = File.join(simulator_application, "Frameworks/Support.dylib")
  write(simulator_dylib, "universal-dynamic-library-fixture")
  simulator_archive = File.join(tmp, "SimulatorExample.app.zip")
  run_command({}, "/usr/bin/ditto", "-c", "-k", "--keepParent", simulator_application, simulator_archive)
  simulator_archive_sha256 = Digest::SHA256.file(simulator_archive).hexdigest
  unsigned_environment = environment.merge("FIXTURE_UNSIGNED" => "1")

  stdout, = run_command(
    unsigned_environment, RUBY, INSPECTOR,
    "--json",
    "--expect-unsigned",
    "--expect-platform", "iphonesimulator",
    "--expect-architecture", "arm64",
    "--expect-architecture", "x86_64",
    "--source-root", project,
    "--expect-clean-source",
    "--expect-source-sha", revision,
    "--expect-artifact-sha256", simulator_archive_sha256,
    "--expect-bundle-id", "com.example.HotwireApp",
    "--expect-rails-origin", "https://example.test",
    simulator_archive
  )
  simulator_inspection = JSON.parse(stdout)
  unless simulator_inspection.fetch("checks").all? { |check| check["passed"] }
    raise "Simulator app archive checks failed"
  end
  raise "Simulator app archive was not inspected" unless simulator_inspection.dig("artifact", "type") == "app-zip"
  raise "Simulator app archive digest was not captured" unless simulator_inspection.dig("artifact", "sha256") == simulator_archive_sha256
  raise "Simulator platform was not captured" unless simulator_inspection.dig("application", "platform") == "iphonesimulator"
  unless simulator_inspection.dig("application", "architectures") == %w[arm64 x86_64]
    raise "Universal Simulator architectures were not captured"
  end
  framework_binary = simulator_inspection.dig("application", "embedded_binaries").find do |binary|
    binary["path"] == "Frameworks/Preview.framework/Preview"
  end
  unless framework_binary && framework_binary["architectures"] == %w[arm64 x86_64]
    raise "Universal embedded-framework architectures were not captured"
  end
  dylib_binary = simulator_inspection.dig("application", "embedded_binaries").find do |binary|
    binary["path"] == "Frameworks/Support.dylib"
  end
  unless dylib_binary && dylib_binary["architectures"] == %w[arm64 x86_64]
    raise "Universal embedded-dylib architectures were not captured"
  end
  unless simulator_inspection.dig("signature", "credential_free")
    raise "Credential-free Simulator app was reported as requiring Apple signing"
  end

  stdout, = run_command(
    environment.merge("FIXTURE_ADHOC" => "1"), RUBY, INSPECTOR,
    "--json", "--expect-unsigned", "--expect-platform", "iphonesimulator", simulator_archive
  )
  adhoc_simulator = JSON.parse(stdout)
  unless adhoc_simulator.dig("signature", "kind") == "adhoc" && adhoc_simulator.dig("signature", "credential_free")
    raise "A credential-free ad hoc Simulator signature was not accepted"
  end

  stdout, = run_command(
    environment.merge("FIXTURE_LINKER_SIGNED" => "1"), RUBY, INSPECTOR,
    "--json", "--expect-unsigned", "--expect-platform", "iphonesimulator", simulator_archive
  )
  linker_signed_simulator = JSON.parse(stdout)
  unless linker_signed_simulator.dig("signature", "linker_signed") && linker_signed_simulator.dig("signature", "credential_free")
    raise "A credential-free linker-signed Simulator app was not accepted"
  end

  stdout, = run_command(
    environment.merge("FIXTURE_LINKER_SPOOF" => "1"), RUBY, INSPECTOR,
    "--json", "--expect-unsigned", "--expect-platform", "iphonesimulator", simulator_archive,
    expect_exit: 2
  )
  linker_spoof = JSON.parse(stdout)
  if linker_spoof.dig("signature", "linker_signed")
    raise "Arbitrary codesign output spoofed the linker-signed marker"
  end
  unless linker_spoof.fetch("checks").any? { |check| check["label"].include?("signature verifies") && !check["passed"] }
    raise "An invalid signature with a linker-signed path was not rejected"
  end

  stdout, = run_command(
    unsigned_environment.merge("FIXTURE_NESTED_IDENTITY" => "1"), RUBY, INSPECTOR,
    "--json", "--expect-unsigned", "--expect-platform", "iphonesimulator", simulator_archive,
    expect_exit: 2
  )
  nested_identity = JSON.parse(stdout)
  unless nested_identity.fetch("checks").any? do |check|
    check["label"].include?("Preview.framework") && check["label"].include?("Apple signing identity") && !check["passed"]
  end
    raise "An identity-signed nested framework was not rejected"
  end

  stdout, = run_command(
    unsigned_environment.merge("FIXTURE_DYLIB_IDENTITY" => "1"), RUBY, INSPECTOR,
    "--json", "--expect-unsigned", "--expect-platform", "iphonesimulator", simulator_archive,
    expect_exit: 2
  )
  dylib_identity = JSON.parse(stdout)
  unless dylib_identity.fetch("checks").any? do |check|
    check["label"].include?("Support.dylib") && check["label"].include?("Apple signing identity") && !check["passed"]
  end
    raise "An identity-signed standalone dylib was not rejected"
  end

  stdout, = run_command(
    environment.merge("FIXTURE_ADHOC" => "1", "FIXTURE_INVALID_NESTED_SIGNATURE" => "1"), RUBY, INSPECTOR,
    "--json", "--expect-unsigned", "--expect-platform", "iphonesimulator", simulator_archive,
    expect_exit: 2
  )
  invalid_nested_signature = JSON.parse(stdout)
  unless invalid_nested_signature.fetch("checks").any? do |check|
    check["label"].include?("Preview.framework") && check["label"].include?("signature verifies") && !check["passed"]
  end
    raise "An invalid nested ad hoc signature was not rejected"
  end

  stdout, = run_command(
    unsigned_environment.merge("FIXTURE_FRAMEWORK_ARCHITECTURES" => "arm64"), RUBY, INSPECTOR,
    "--json", "--expect-unsigned", "--expect-platform", "iphonesimulator",
    "--expect-architecture", "arm64", "--expect-architecture", "x86_64",
    simulator_archive,
    expect_exit: 2
  )
  missing_architecture = JSON.parse(stdout)
  unless missing_architecture.fetch("checks").any? do |check|
    check["label"].include?("Preview.framework") && check["label"].end_with?("x86_64") && !check["passed"]
  end
    raise "A missing embedded-framework Simulator architecture was not rejected"
  end

  stdout, = run_command(
    unsigned_environment.merge("FIXTURE_DYLIB_ARCHITECTURES" => "arm64"), RUBY, INSPECTOR,
    "--json", "--expect-unsigned", "--expect-platform", "iphonesimulator",
    "--expect-architecture", "arm64", "--expect-architecture", "x86_64",
    simulator_archive,
    expect_exit: 2
  )
  missing_dylib_architecture = JSON.parse(stdout)
  unless missing_dylib_architecture.fetch("checks").any? do |check|
    check["label"].include?("Support.dylib") && check["label"].end_with?("x86_64") && !check["passed"]
  end
    raise "A missing standalone-dylib Simulator architecture was not rejected"
  end

  stdout, = run_command(environment, RUBY, INSPECTOR, "--json", "--expect-unsigned", simulator_archive, expect_exit: 2)
  signed_simulator = JSON.parse(stdout)
  unless signed_simulator.fetch("checks").any? { |check| check["label"].include?("Apple signing identity") && !check["passed"] }
    raise "A signed Simulator archive was not rejected when unsigned was required"
  end

  stdout, = run_command(
    unsigned_environment, RUBY, INSPECTOR,
    "--json", "--expect-unsigned", "--expect-artifact-sha256", "0" * 64, simulator_archive,
    expect_exit: 2
  )
  wrong_simulator_digest = JSON.parse(stdout)
  unless wrong_simulator_digest.fetch("checks").any? { |check| check["label"] == "artifact SHA-256" && !check["passed"] }
    raise "A mismatched Simulator archive digest was not rejected"
  end

  outside_binary = File.join(tmp, "OutsideBinary")
  write(outside_binary, "outside-binary-fixture")
  {
    "absolute" => outside_binary,
    "traversal" => "../OutsideBinary"
  }.each do |name, unsafe_executable|
    unsafe_application = File.join(tmp, "UnsafeExecutable-#{name}.app")
    FileUtils.mkdir_p(unsafe_application)
    write(File.join(unsafe_application, "Info.plist"), info_plist(executable: unsafe_executable, platform: "iphonesimulator"))
    stdout, = run_command(
      unsigned_environment, RUBY, INSPECTOR, "--json", "--expect-unsigned", unsafe_application,
      expect_exit: 2
    )
    unsafe_executable_report = JSON.parse(stdout)
    unless unsafe_executable_report.fetch("checks").any? do |check|
      check["label"].include?("executable is present and contained") && !check["passed"]
    end
      raise "An #{name} CFBundleExecutable path was not rejected"
    end
    if unsafe_executable_report.dig("application", "embedded_binaries").any? { |binary| binary["sha256"] == Digest::SHA256.file(outside_binary).hexdigest }
      raise "An #{name} CFBundleExecutable path escaped the application"
    end
  end
  external_framework = File.join(tmp, "External.framework")
  FileUtils.mkdir_p(external_framework)
  write(File.join(external_framework, "Info.plist"), info_plist(executable: "External", platform: "iphonesimulator"))
  write(File.join(external_framework, "External"), "external-framework-binary")
  {
    "framework" => ["Frameworks/Preview.framework", external_framework],
    "dylib" => ["Frameworks/Support.dylib", outside_binary]
  }.each do |name, (relative_path, target)|
    symlinked_application = File.join(tmp, "Symlinked-#{name}.app")
    FileUtils.cp_r(simulator_application, symlinked_application)
    link_path = File.join(symlinked_application, relative_path)
    FileUtils.rm_rf(link_path)
    File.symlink(target, link_path)
    _, stderr = run_command(
      unsigned_environment, RUBY, INSPECTOR, "--json", "--expect-unsigned", symlinked_application,
      expect_exit: 1
    )
    raise "A symlinked #{name} was not rejected" unless stderr.include?("symbolic link")
  end

  escaped_archive = File.join(tmp, "Escaped.xcarchive")
  FileUtils.mkdir_p(File.join(escaped_archive, "Products"))
  external_applications = File.join(tmp, "ExternalApplications")
  FileUtils.mkdir_p(external_applications)
  FileUtils.cp_r(simulator_application, File.join(external_applications, "External.app"))
  File.symlink(external_applications, File.join(escaped_archive, "Products/Applications"))
  _, stderr = run_command(
    unsigned_environment, RUBY, INSPECTOR, "--json", "--expect-unsigned", escaped_archive,
    expect_exit: 1
  )
  unless stderr.include?("remain inside the xcarchive")
    raise "An xcarchive application behind a symlinked ancestor was not rejected"
  end

  nested_payload = File.join(tmp, "NestedPayload")
  FileUtils.mkdir_p(nested_payload)
  FileUtils.cp_r(simulator_application, File.join(nested_payload, "SimulatorExample.app"))
  nested_simulator_archive = File.join(tmp, "NestedSimulator.app.zip")
  run_command({}, "/usr/bin/ditto", "-c", "-k", "--keepParent", nested_payload, nested_simulator_archive)
  _, stderr = run_command(
    unsigned_environment, RUBY, INSPECTOR, "--json", "--expect-unsigned", nested_simulator_archive,
    expect_exit: 1
  )
  unless stderr.include?("only one top-level application")
    raise "A non-canonical Simulator archive layout was not rejected"
  end

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
