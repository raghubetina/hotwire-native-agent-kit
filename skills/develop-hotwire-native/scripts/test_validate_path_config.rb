#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "socket"

RUBY = RbConfig.ruby
VALIDATOR = File.expand_path("validate_path_config.rb", __dir__)

def path_configuration(pattern)
  JSON.generate(
    "settings" => {},
    "rules" => [
      { "patterns" => [pattern], "properties" => {} }
    ]
  )
end

def run_validator(*arguments)
  stdout, stderr, status = Open3.capture3(RUBY, VALIDATOR, *arguments)
  return stdout if status.success?

  warn stdout
  warn stderr
  raise "Path configuration validator exited with #{status.exitstatus}"
end

remote_document = path_configuration("^/remote$")
server = TCPServer.new("127.0.0.1", 0)
request_count = 0
server_thread = Thread.new do
  client = server.accept
  request_count += 1
  client.gets
  while (line = client.gets)
    break if line == "\r\n"
  end
  response_headers = [
    "HTTP/1.1 200 OK",
    "Content-Type: application/json",
    "Content-Length: #{remote_document.bytesize}",
    "Connection: close",
    "",
    ""
  ].join("\r\n")
  client.write(response_headers)
  client.write(remote_document)
ensure
  client.close if client && !client.closed?
  server.close unless server.closed?
end

begin
  url = "http://127.0.0.1:#{server.addr[1]}/path-configuration.json"
  result = JSON.parse(run_validator("--json", "--compare", url, url))
  raise "Live URL validation reported errors: #{result.fetch('errors').join(', ')}" unless result.fetch("errors").empty?
  raise "Live URL was fetched more than once" unless request_count == 1
  unless result.fetch("info").include?("Both files contain the same pattern strings.")
    raise "Same-source comparison result was not reported"
  end
ensure
  server.close unless server.closed?
  unless server_thread.join(5)
    server_thread.kill
    raise "Local HTTP fixture did not finish"
  end
end
server_thread.value

compare_document = path_configuration("^/android$")
current_document = path_configuration("^/ios$")
bash = <<~'BASH'
  exec "$1" "$2" --json --compare <(printf '%s' "$3") <(printf '%s' "$4")
BASH
stdout, stderr, status = Open3.capture3(
  "/bin/bash", "-c", bash, "path-config-stream-test",
  RUBY, VALIDATOR, compare_document, current_document
)
unless status.success?
  warn stdout
  warn stderr
  raise "Process-substitution validation exited with #{status.exitstatus}"
end

stream_result = JSON.parse(stdout)
unless stream_result.fetch("errors").empty?
  raise "Process-substitution comparison reported errors: #{stream_result.fetch('errors').join(', ')}"
end
stream_info = stream_result.fetch("info").join("\n")
raise "Current stream pattern was not compared" unless stream_info.include?("^/ios$")
raise "Comparison stream pattern was not compared" unless stream_info.include?("^/android$")

puts "Path configuration URL and single-read stream tests passed."
