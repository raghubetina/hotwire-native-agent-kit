# frozen_string_literal: true

require "digest"
require "json"
require "open3"
# `pathname` is not loaded by the same standard-library dependencies on every supported macOS Ruby.
# standard:disable Lint/RedundantRequireStatement
require "pathname"
# standard:enable Lint/RedundantRequireStatement
require "rexml/document"
require "tmpdir"
require "time"

module DeployIOSSupport
  SUPPORTED_ENTITLEMENT_KEYS = %w[
    application-identifier
    aps-environment
    beta-reports-active
    com.apple.developer.associated-domains
    com.apple.developer.team-identifier
    com.apple.security.application-groups
    get-task-allow
    keychain-access-groups
  ].freeze

  class Error < StandardError; end
  class CommandError < Error; end

  module_function

  def command_path(name)
    override = ENV["DEPLOY_IOS_TOOL_#{name.upcase.tr("-", "_")}"]
    return override unless override.nil? || override.empty?

    absolute = "/usr/bin/#{name}"
    File.executable?(absolute) ? absolute : name
  end

  def capture(name, *arguments, allow_failure: false)
    stdout, stderr, status = Open3.capture3(command_path(name), *arguments.map(&:to_s))
    unless status.success? || allow_failure
      raise CommandError, "#{name} failed with exit status #{status.exitstatus}"
    end

    [stdout, stderr, status]
  rescue Errno::ENOENT
    raise CommandError, "Required tool is unavailable: #{name}"
  end

  def git_evidence(root)
    revision, = capture("git", "-C", root.to_s, "rev-parse", "HEAD", allow_failure: true)
    status, _, result = capture(
      "git", "-C", root.to_s, "status", "--porcelain=v1", "-z", "--untracked-files=normal",
      allow_failure: true
    )
    return {"available" => false} unless result.success? && revision.match?(/\A[0-9a-f]{40}\s*\z/)

    entries = status.split("\0").reject(&:empty?)
    {
      "available" => true,
      "revision" => revision.strip,
      "dirty" => !entries.empty?,
      "changed_file_count" => entries.length
    }
  end

  def relative(root, path)
    Pathname.new(path).expand_path.relative_path_from(Pathname.new(root).expand_path).to_s
  rescue ArgumentError
    File.basename(path.to_s)
  end

  def safe_text(path, limit: 5 * 1024 * 1024)
    return nil unless File.file?(path)
    return nil if File.size(path) > limit

    content = File.binread(path)
    content.force_encoding(Encoding::UTF_8)
    content.valid_encoding? ? content : nil
  rescue Errno::EACCES, Errno::ENOENT
    nil
  end

  def directory_manifest_sha256(directory)
    root = Pathname.new(directory).expand_path
    digest = Digest::SHA256.new

    Dir.glob(root.join("**/*").to_s, File::FNM_DOTMATCH).sort.each do |entry|
      next if [".", ".."].include?(File.basename(entry))

      path = Pathname.new(entry)
      stat = File.lstat(path)
      relative_path = path.relative_path_from(root).to_s
      digest << relative_path << "\0" << stat.mode.to_s(8) << "\0"

      if stat.file?
        File.open(path, "rb") do |file|
          loop do
            chunk = file.read(1024 * 1024)
            break unless chunk

            digest << chunk
          end
        end
      elsif stat.symlink?
        digest << "symlink\0" << File.readlink(path)
      elsif stat.directory?
        digest << "directory"
      else
        digest << "other"
      end
      digest << "\0"
    end

    digest.hexdigest
  end

  def plist(path_or_xml)
    candidate = path_or_xml.to_s
    content = if !candidate.lstrip.start_with?("<") && File.file?(candidate)
      File.binread(path_or_xml.to_s)
    else
      candidate
    end

    if content.start_with?("bplist")
      Dir.mktmpdir("deploy-ios-plist") do |tmp|
        converted = File.join(tmp, "converted.plist")
        capture("plutil", "-convert", "xml1", "-o", converted, path_or_xml.to_s)
        content = File.binread(converted)
      end
    end

    document = REXML::Document.new(content)
    root = document.elements["plist/*"]
    raise Error, "Unable to find plist root" unless root

    parse_plist_element(root)
  rescue REXML::ParseException => error
    raise Error, "Invalid plist: #{error.message.lines.first.to_s.strip}"
  end

  def parse_plist_element(element)
    case element.name
    when "dict"
      values = {}
      children = element.elements.to_a
      index = 0
      while index < children.length
        key = children[index]
        value = children[index + 1]
        raise Error, "Malformed plist dictionary" unless key&.name == "key" && value

        values[key.text.to_s] = parse_plist_element(value)
        index += 2
      end
      values
    when "array"
      element.elements.map { |child| parse_plist_element(child) }
    when "string", "date", "data"
      element.text.to_s.strip
    when "integer"
      Integer(element.text.to_s)
    when "real"
      Float(element.text.to_s)
    when "true"
      true
    when "false"
      false
    end
  end

  def selected_entitlements(values)
    return {} unless values.is_a?(Hash)

    {
      "application_identifier" => values["application-identifier"],
      "team_identifier" => values["com.apple.developer.team-identifier"],
      "aps_environment" => values["aps-environment"],
      "associated_domains" => Array(values["com.apple.developer.associated-domains"]).sort,
      "application_groups" => Array(values["com.apple.security.application-groups"]).sort,
      "keychain_access_groups" => Array(values["keychain-access-groups"]).sort,
      "get_task_allow" => values["get-task-allow"],
      "beta_reports_active" => values["beta-reports-active"]
    }.reject { |_, value| value.nil? || value == [] }
  end

  def result_exit!(report, json: false)
    puts "Deployment verification" unless json
    puts JSON.pretty_generate(report)

    exit((report.fetch("checks").all? { |check| check.fetch("passed") }) ? 0 : 2)
  end

  def check(label, expected, actual, comparator: nil)
    passed = if comparator
      comparator.call(expected, actual)
    else
      expected == actual
    end
    {
      "label" => label,
      "passed" => passed,
      "expected" => expected,
      "actual" => actual
    }
  end

  def redact_error(error, sensitive_paths)
    message = error.message.to_s.lines.first.to_s.strip
    sensitive_paths.compact.sort_by { |path| -path.to_s.length }.each do |path|
      expanded = File.expand_path(path.to_s)
      message = message.gsub(expanded, "[path]")
    end
    message
  end
end
