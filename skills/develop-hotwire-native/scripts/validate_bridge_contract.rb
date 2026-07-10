#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "pathname"
require "set"

options = { root: nil, web: nil, ios: nil, android: nil, json: false, skip_payload: false }
parser = OptionParser.new do |opts|
  opts.banner = "Usage: validate_bridge_contract.rb (--root ROOT | --web DIR --ios DIR --android DIR) [options]"
  opts.on("--root ROOT", "Root containing conventional web/ios/android trees") { |value| options[:root] = value }
  opts.on("--web DIR", "Web bridge-controller directory") { |value| options[:web] = value }
  opts.on("--ios DIR", "iOS source directory") { |value| options[:ios] = value }
  opts.on("--android DIR", "Android source directory") { |value| options[:android] = value }
  opts.on("--skip-payload", "Skip heuristic payload-field comparison") { options[:skip_payload] = true }
  opts.on("--json", "Emit JSON") { options[:json] = true }
end
parser.parse!

if options[:root]
  root = File.expand_path(options[:root])
  options[:web] ||= File.join(root, "app/javascript/controllers/bridge")
  options[:ios] ||= File.join(root, "ios")
  options[:android] ||= File.join(root, "android")
end

abort parser.to_s unless options.values_at(:web, :ios, :android).all?

def source_files(directory, extensions)
  return [] unless Dir.exist?(directory)

  Dir.glob(File.join(directory, "**", "*"))
    .select { |path| File.file?(path) && extensions.include?(File.extname(path)) }
    .reject { |path| path.split(File::SEPARATOR).any? { |part| [".git", "node_modules", "build", "Pods"].include?(part) } }
end

def web_components(directory)
  source_files(directory, [".js", ".ts"]).map do |path|
    content = File.read(path)
    name = content[/static\s+component\s*=\s*["']([^"']+)["']/, 1]
    next unless name

    events = content.scan(/(?:this\.)?send\(\s*["']([^"']+)["']/).flatten.to_set
    payload_fields = Set.new
    content.scan(/(?:this\.)?send\(\s*["'][^"']+["']\s*,\s*\{(.*?)\}\s*[,)]/m) do |body|
      body.first.scan(/(?:^|,)\s*([A-Za-z_$][\w$]*)\s*(?::|,|$)/).flatten.each { |field| payload_fields << field }
    end

    [name, { path: path, events: events, payload_fields: payload_fields, disconnect_method: content.match?(/\bdisconnect\s*\(/) }]
  end.compact.to_h
end

def ios_components(directory)
  source_files(directory, [".swift"]).map do |path|
    content = File.read(path)
    name = content[/(?:nonisolated\s+)?class\s+var\s+name\s*:\s*String\s*\{\s*["']([^"']+)["']/, 1]
    next unless name

    events = content.scan(/case\s+\.([A-Za-z_][\w]*)/).flatten.to_set
    events.merge(content.scan(/case\s+["']([^"']+)["']/).flatten)
    fields = content.scan(/\blet\s+([A-Za-z_][\w]*)\s*:/).flatten.to_set
    [name, { path: path, events: events, payload_fields: fields }]
  end.compact.to_h
end

def android_components(directory)
  files = source_files(directory, [".kt"])
  registrations = {}
  files.each do |path|
    File.read(path).scan(/BridgeComponentFactory\(\s*["']([^"']+)["']\s*,\s*::([A-Za-z_][\w]*)/) do |name, klass|
      registrations[klass] = name
    end
  end

  files.map do |path|
    content = File.read(path)
    klass = content[/class\s+([A-Za-z_][\w]*)\s*\(/, 1]
    next unless klass && registrations[klass]

    events = content.scan(/["']([^"']+)["']\s*->/).flatten.to_set
    aliases = content.scan(/@SerialName\(\s*["']([^"']+)["']\s*\)\s*(?:val|var)\s+([A-Za-z_][\w]*)/).to_h
    fields = content.scan(/\b(?:val|var)\s+([A-Za-z_][\w]*)\s*:/).flatten.to_set
    aliases.each { |wire_name, local_name| fields.delete(local_name); fields << wire_name }
    [registrations[klass], { path: path, events: events, payload_fields: fields }]
  end.compact.to_h
end

web = web_components(options[:web])
ios = ios_components(options[:ios])
android = android_components(options[:android])
errors = []
warnings = []

all_names = (web.keys + ios.keys + android.keys).uniq.sort
all_names.each do |name|
  missing = []
  missing << "web" unless web.key?(name)
  missing << "iOS" unless ios.key?(name)
  missing << "Android registration/source" unless android.key?(name)
  errors << "Component #{name.inspect} is missing: #{missing.join(', ')}." unless missing.empty?

  next unless web[name]

  { "iOS" => ios[name], "Android" => android[name] }.each do |platform, native|
    next unless native

    absent_events = web[name][:events] - native[:events]
    errors << "#{platform} component #{name.inspect} does not handle web events: #{absent_events.to_a.sort.join(', ')}." unless absent_events.empty?

    next if options[:skip_payload]

    likely_missing_fields = web[name][:payload_fields] - native[:payload_fields]
    unless likely_missing_fields.empty?
      warnings << "#{platform} component #{name.inspect} may not decode web payload fields: #{likely_missing_fields.to_a.sort.join(', ')} (heuristic)."
    end
  end

  if web[name][:events].include?("disconnect") && !web[name][:disconnect_method]
    warnings << "Web component #{name.inspect} sends disconnect but has no disconnect() lifecycle method."
  end
end

result = {
  web_directory: File.expand_path(options[:web]),
  ios_directory: File.expand_path(options[:ios]),
  android_directory: File.expand_path(options[:android]),
  components: { web: web.keys.sort, ios: ios.keys.sort, android: android.keys.sort },
  errors: errors,
  warnings: warnings
}

if options[:json]
  puts JSON.pretty_generate(result)
else
  puts "Bridge contract: web=#{web.length}, iOS=#{ios.length}, Android=#{android.length}"
  errors.each { |message| puts "ERROR: #{message}" }
  warnings.each { |message| puts "WARN: #{message}" }
  puts "OK" if errors.empty? && warnings.empty?
end

exit(errors.empty? ? 0 : 1)
