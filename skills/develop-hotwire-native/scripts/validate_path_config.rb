#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "optparse"
require "set"
require "timeout"
require "uri"

options = { platform: "auto", compare: nil, json: false }
parser = OptionParser.new do |opts|
  opts.banner = "Usage: validate_path_config.rb [options] SOURCE"
  opts.on("--platform PLATFORM", %w[auto ios android], "auto, ios, or android") { |value| options[:platform] = value }
  opts.on("--compare SOURCE", "Compare patterns with another file or URL") { |value| options[:compare] = value }
  opts.on("--json", "Emit JSON") { options[:json] = true }
end
parser.parse!

file = ARGV.shift
abort parser.to_s unless file

ALLOWED_CONTEXTS = %w[default modal].freeze
SHARED_PRESENTATIONS = %w[default pop replace clear_all replace_root refresh none].freeze
ANDROID_PRESENTATIONS = (SHARED_PRESENTATIONS + %w[push]).freeze
QUERY_PRESENTATIONS = %w[default replace].freeze
MODAL_STYLES = %w[medium large full page_sheet form_sheet].freeze
BOOLEAN_KEYS = %w[pull_to_refresh_enabled modal_dismiss_gesture_enabled animated historical_location].freeze
IOS_KEYS = %w[view_controller modal_style modal_dismiss_gesture_enabled].freeze
ANDROID_KEYS = %w[uri fallback_uri title].freeze
CATCH_ALL = [".*", "^.*$", "/.*", "^/.*$"].freeze
HTTP_OPEN_TIMEOUT = 10
HTTP_READ_TIMEOUT = 10
MAX_HTTP_REDIRECTS = 5

def http_uri(source)
  return nil unless source.match?(%r{\Ahttps?://}i)

  uri = URI.parse(source)
  raise URI::InvalidURIError, "URL must include a host" unless uri.is_a?(URI::HTTP) && uri.host

  uri
end

def fetch_http(uri, redirects_remaining = MAX_HTTP_REDIRECTS)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = HTTP_OPEN_TIMEOUT
  http.read_timeout = HTTP_READ_TIMEOUT

  request = Net::HTTP::Get.new(uri.request_uri)
  request["User-Agent"] = "hotwire-native-agent-kit-path-validator"
  response = http.request(request)

  case response
  when Net::HTTPSuccess
    response.body
  when Net::HTTPRedirection
    raise "Too many HTTP redirects while fetching #{uri}" if redirects_remaining.zero?

    location = response["location"]
    raise "HTTP redirect from #{uri} did not include a Location header" if location.nil? || location.empty?

    redirected_uri = URI.join(uri.to_s, location)
    unless redirected_uri.is_a?(URI::HTTP)
      raise "HTTP redirect from #{uri} uses unsupported scheme #{redirected_uri.scheme.inspect}"
    end

    fetch_http(redirected_uri, redirects_remaining - 1)
  else
    raise "HTTP request failed for #{uri}: #{response.code} #{response.message}"
  end
rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
  raise "Unable to fetch #{uri}: #{error.class}: #{error.message}"
end

def load_json(source)
  uri = http_uri(source)
  contents = uri ? fetch_http(uri) : File.read(source)
  JSON.parse(contents)
rescue Errno::ENOENT
  raise "Source not found: #{source}"
rescue URI::InvalidURIError => error
  raise "Invalid URL #{source.inspect}: #{error.message}"
rescue JSON::ParserError => error
  raise "Invalid JSON in #{source}: #{error.message}"
end

def load_json_once(source, cache)
  unless cache.key?(source)
    cache[source] = begin
      { document: load_json(source) }
    rescue StandardError => error
      { error: error }
    end
  end

  result = cache.fetch(source)
  raise result[:error] if result.key?(:error)

  result.fetch(:document)
end

def infer_platform(rules)
  keys = rules.flat_map { |rule| rule.fetch("properties", {}).keys }
  return "android" if (keys & ANDROID_KEYS).any?
  return "ios" if (keys & IOS_KEYS).any?

  "auto"
end

def patterns_from(document)
  document.fetch("rules", []).flat_map { |rule| rule.fetch("patterns", []) }.to_set
end

errors = []
warnings = []
info = []
source_cache = {}

begin
  document = load_json_once(file, source_cache)
rescue StandardError => error
  errors << error.message
  document = {}
end

unless document.is_a?(Hash)
  errors << "Top-level JSON value must be an object."
  document = {}
end

settings = document.fetch("settings", {})
rules = document["rules"]
errors << "settings must be an object when present." unless settings.is_a?(Hash)
errors << "rules must be an array." unless rules.is_a?(Array)
rules = [] unless rules.is_a?(Array)

platform = options[:platform] == "auto" ? infer_platform(rules) : options[:platform]
catch_all_indexes = []

rules.each_with_index do |rule, index|
  label = "rule #{index + 1}"
  unless rule.is_a?(Hash)
    errors << "#{label} must be an object."
    next
  end

  patterns = rule["patterns"]
  properties = rule["properties"]
  errors << "#{label} patterns must be a non-empty array." unless patterns.is_a?(Array) && !patterns.empty?
  errors << "#{label} properties must be an object." unless properties.is_a?(Hash)
  next unless patterns.is_a?(Array) && properties.is_a?(Hash)

  patterns.each do |pattern|
    unless pattern.is_a?(String) && !pattern.empty?
      errors << "#{label} contains a non-string or empty pattern."
      next
    end

    begin
      Regexp.new(pattern)
    rescue RegexpError => error
      errors << "#{label} pattern #{pattern.inspect} is invalid in the conservative Ruby check: #{error.message}"
    end

    catch_all_indexes << index if CATCH_ALL.include?(pattern)
    warnings << "#{label} pattern #{pattern.inspect} is short and unanchored; verify it cannot match a larger route." if pattern.start_with?("/") && pattern.length < 12 && !pattern.end_with?("$", ".*")
  end

  context = properties["context"]
  errors << "#{label} context must be one of #{ALLOWED_CONTEXTS.join(', ')}." if context && !ALLOWED_CONTEXTS.include?(context)

  presentation = properties["presentation"]
  allowed_presentations = platform == "android" ? ANDROID_PRESENTATIONS : SHARED_PRESENTATIONS
  if presentation == "modal"
    errors << "#{label} uses presentation=modal; use context=modal."
  elsif presentation && !allowed_presentations.include?(presentation)
    errors << "#{label} presentation #{presentation.inspect} is invalid for platform #{platform}."
  end

  query_presentation = properties["query_string_presentation"]
  if query_presentation && !QUERY_PRESENTATIONS.include?(query_presentation)
    errors << "#{label} query_string_presentation must be default or replace."
  end

  modal_style = properties["modal_style"]
  errors << "#{label} modal_style #{modal_style.inspect} is invalid." if modal_style && !MODAL_STYLES.include?(modal_style)

  BOOLEAN_KEYS.each do |key|
    next unless properties.key?(key)
    errors << "#{label} #{key} must be true or false." unless [true, false].include?(properties[key])
  end

  if platform == "ios"
    (properties.keys & ANDROID_KEYS).each { |key| warnings << "#{label} #{key} is Android-specific unless custom iOS code consumes it." }
  elsif platform == "android"
    (properties.keys & IOS_KEYS).each { |key| warnings << "#{label} #{key} is iOS-specific unless custom Android code consumes it." }
  end
end

if catch_all_indexes.any? && catch_all_indexes.max.positive?
  warnings << "A catch-all rule appears after a specific rule. Later matches override earlier properties; put the baseline first."
end

if platform == "android" && rules.any? && catch_all_indexes.empty?
  warnings << "No explicit Android catch-all baseline was found. defaultFragmentDestination can still work, but a web URI baseline makes fallback policy reviewable."
end

if options[:compare]
  begin
    current_patterns = patterns_from(load_json_once(file, source_cache))
    other_patterns = patterns_from(load_json_once(options[:compare], source_cache))
    only_current = (current_patterns - other_patterns).to_a.sort
    only_other = (other_patterns - current_patterns).to_a.sort
    info << "Patterns only in #{file}: #{only_current.join(', ')}" unless only_current.empty?
    info << "Patterns only in #{options[:compare]}: #{only_other.join(', ')}" unless only_other.empty?
    info << "Both files contain the same pattern strings." if only_current.empty? && only_other.empty?
  rescue StandardError => error
    errors << "Comparison failed: #{error.message}"
  end
end

result = { file: file, platform: platform, rules: rules.length, errors: errors, warnings: warnings.uniq, info: info }

if options[:json]
  puts JSON.pretty_generate(result)
else
  puts "Path configuration: #{file} (platform: #{platform}, rules: #{rules.length})"
  errors.each { |message| puts "ERROR: #{message}" }
  warnings.uniq.each { |message| puts "WARN: #{message}" }
  info.each { |message| puts "INFO: #{message}" }
  puts "OK" if errors.empty? && warnings.empty?
end

exit(errors.empty? ? 0 : 1)
