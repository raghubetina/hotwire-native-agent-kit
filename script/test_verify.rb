#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
# `pathname` is not loaded by the same standard-library dependencies on every supported Ruby.
# standard:disable Lint/RedundantRequireStatement
require "pathname"
# standard:enable Lint/RedundantRequireStatement
require "rbconfig"
require "tmpdir"

SOURCE_ROOT = Pathname.new(__dir__).join("..").expand_path

def copy_repository(destination)
  SOURCE_ROOT.children.each do |entry|
    next if entry.basename.to_s == ".git"

    FileUtils.cp_r(entry, destination, preserve: true)
  end
end

def run_verifier(root)
  stdout, stderr, status = Open3.capture3(RbConfig.ruby, "script/verify", chdir: root.to_s)
  [status.success?, stdout + stderr]
end

def with_repository
  Dir.mktmpdir("agent-kit-verify-") do |directory|
    root = Pathname.new(directory)
    copy_repository(root)
    yield root
  end
end

failures = []

with_repository do |root|
  success, output = run_verifier(root)
  failures << "expected the unmodified release to verify:\n#{output}" unless success
end

with_repository do |root|
  manifest_path = root.join(".codex-plugin/plugin.json")
  manifest = JSON.parse(manifest_path.read)
  manifest["version"] = "9.9.9"
  manifest_path.write(JSON.pretty_generate(manifest) + "\n")
  success, output = run_verifier(root)
  failures << "expected a mismatched manifest version to fail" if success
  failures << "version mismatch did not identify the changelog" unless output.include?("first changelog release")
end

with_repository do |root|
  FileUtils.mkdir_p(root.join("skills/unreviewed"))
  root.join("skills/unreviewed/SKILL.md").write("placeholder\n")
  success, output = run_verifier(root)
  failures << "expected an undeclared Skill to fail" if success
  failures << "unexpected Skill did not identify the inventory mismatch" unless output.include?("Skill inventory mismatch")
end

with_repository do |root|
  marker = "<" * 7 + " unresolved\n"
  root.join("README.md").open("a") { |file| file.write(marker) }
  success, output = run_verifier(root)
  failures << "expected a merge-conflict marker to fail" if success
  failures << "conflict marker did not identify its source" unless output.include?("merge-conflict marker")
end

with_repository do |root|
  manifest = JSON.parse(root.join(".codex-plugin/plugin.json").read)
  version = manifest.fetch("version")
  readme = root.join("README.md").read
  root.join("README.md").write(readme.sub("--pin v#{version}", "--pin v9.9.9"))
  success, output = run_verifier(root)
  failures << "expected a stale README install pin to fail" if success
  failures << "stale install pin did not identify the release mismatch" unless output.include?("stale release reference")
end

with_repository do |root|
  manifest = JSON.parse(root.join(".codex-plugin/plugin.json").read)
  version = manifest.fetch("version")
  readme = root.join("README.md").read
  explicit = "develop-hotwire-native \\\n  --pin v#{version}"
  root.join("README.md").write(readme.sub(explicit, "develop-hotwire-native@v#{version}"))
  success, output = run_verifier(root)
  failures << "expected name@version without --pin to fail" if success
  failures << "implicit pin did not identify the name@version problem" unless output.include?("must not use name@version")
end

with_repository do |root|
  readme = root.join("README.md")
  readme.write(readme.read.sub("GitHub CLI](https://cli.github.com/) 2.95 or newer", "GitHub CLI](https://cli.github.com/) 2.90 or newer"))
  success, output = run_verifier(root)
  failures << "expected an obsolete GitHub CLI minimum to fail" if success
  failures << "obsolete GitHub CLI minimum did not identify the required version" unless output.include?("GitHub CLI 2.95 or newer")
end

with_repository do |root|
  workflow = root.join(".github/workflows/ci.yml")
  workflow.write(workflow.read.sub("runs-on: macos-15", "runs-on: ubuntu-24.04"))
  success, output = run_verifier(root)
  failures << "expected removal of the macOS deployment test lane to fail" if success
  failures << "missing macOS lane did not identify the deployment-tool requirement" unless output.include?("deployment tools")
end

with_repository do |root|
  workflow = root.join(".github/workflows/ci.yml")
  workflow.write(workflow.read.sub(/actions\/checkout@[0-9a-f]{40}/, "actions/checkout@v7"))
  success, output = run_verifier(root)
  failures << "expected a floating GitHub Action reference to fail" if success
  failures << "floating Action did not identify the full-SHA requirement" unless output.include?("full commit SHA")
end

with_repository do |root|
  FileUtils.mkdir_p(root.join("secrets"))
  root.join("secrets/distribution.pfx").write("opaque fixture")
  success, output = run_verifier(root)
  failures << "expected an arbitrarily named signing-key file to fail" if success
  failures << "signing-key filename did not identify key material" unless output.include?("looks like signing or API-key material")
end

with_repository do |root|
  marker = ["-----BEGIN", "ENCRYPTED PRIVATE KEY-----"].join(" ")
  root.join("README.md").open("a") { |file| file.write("\n#{marker}\n#{"A" * 64}\n") }
  success, output = run_verifier(root)
  failures << "expected encrypted private-key content to fail" if success
  failures << "private-key content did not identify key material" unless output.include?("private-key material")
end

with_repository do |root|
  marker = ["-----BEGIN", "PRIVATE KEY-----"].join(" ")
  root.join("README.md").open("a") { |file| file.write("\nDocumentation may name `#{marker}` without containing key payload.\n") }
  success, output = run_verifier(root)
  failures << "expected a documentation-only key marker to remain valid:\n#{output}" unless success
end

abort failures.join("\n\n") unless failures.empty?

puts "Release verifier mutation tests passed."
