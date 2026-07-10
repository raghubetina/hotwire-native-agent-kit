#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

SKILL_ROOT = File.expand_path("..", __dir__)
RUBY = RbConfig.ruby

def run_command(*command, expect_success: true)
  stdout, stderr, status = Open3.capture3(*command)
  if status.success? != expect_success
    warn "Command: #{command.join(' ')}"
    warn stdout
    warn stderr
    raise "Expected success=#{expect_success}, got exit #{status.exitstatus}"
  end
  [stdout, stderr]
end

path_validator = File.join(SKILL_ROOT, "scripts/validate_path_config.rb")
bridge_validator = File.join(SKILL_ROOT, "scripts/validate_bridge_contract.rb")
project_auditor = File.join(SKILL_ROOT, "scripts/audit_project.rb")
path_templates = File.join(SKILL_ROOT, "assets/templates/path-configuration")
bridge_template = File.join(SKILL_ROOT, "assets/templates/bridge-form")

run_command(RUBY, path_validator, "--platform", "ios", File.join(path_templates, "ios.json"))
run_command(RUBY, path_validator, "--platform", "android", File.join(path_templates, "android.json"))
run_command(
  RUBY, bridge_validator,
  "--web", bridge_template,
  "--ios", bridge_template,
  "--android", bridge_template
)

Dir.mktmpdir("hotwire-native-skill-test") do |tmp|
  invalid_path = File.join(tmp, "invalid-path.json")
  File.write(invalid_path, JSON.pretty_generate(
    "settings" => {},
    "rules" => [
      { "patterns" => ["/new"], "properties" => { "presentation" => "modal" } }
    ]
  ))
  stdout, = run_command(RUBY, path_validator, invalid_path, expect_success: false)
  raise "Invalid modal presentation was not reported" unless stdout.include?("presentation=modal")

  web = File.join(tmp, "web")
  ios = File.join(tmp, "ios")
  android = File.join(tmp, "android")
  [web, ios, android].each { |directory| FileUtils.mkdir_p(directory) }

  File.write(File.join(web, "form_controller.js"), <<~JS)
    class FormComponent {
      static component = "form"
      connect() { this.send("connect", { submitTitle: "Save" }) }
      disconnect() { this.send("disconnect") }
    }
  JS
  File.write(File.join(ios, "FormComponent.swift"), <<~SWIFT)
    final class FormComponent {
      override nonisolated class var name: String { "form" }
      enum Event: String { case connect }
      func receive(_ event: Event) { switch event { case .connect: break } }
      struct MessageData { let submitTitle: String }
    }
  SWIFT
  File.write(File.join(android, "Bridge.kt"), <<~KOTLIN)
    fun register() { BridgeComponentFactory("form", ::FormComponent) }
    class FormComponent(name: String) {
      fun receive(event: String) = when (event) {
        "connect" -> Unit
        "disconnect" -> Unit
        else -> Unit
      }
      data class MessageData(val submitTitle: String)
    }
  KOTLIN
  stdout, = run_command(
    RUBY, bridge_validator,
    "--web", web,
    "--ios", ios,
    "--android", android,
    expect_success: false
  )
  raise "Missing iOS disconnect event was not reported" unless stdout.include?("does not handle web events: disconnect")

  project = File.join(tmp, "project")
  FileUtils.mkdir_p(File.join(project, "config"))
  FileUtils.mkdir_p(File.join(project, "app/controllers"))
  FileUtils.mkdir_p(File.join(project, "app/views/configurations"))
  FileUtils.mkdir_p(File.join(project, "app/javascript/controllers/bridge"))
  FileUtils.mkdir_p(File.join(project, "ios/App.xcodeproj"))
  FileUtils.mkdir_p(File.join(project, "ios/App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"))
  FileUtils.mkdir_p(File.join(project, "android/app"))
  FileUtils.mkdir_p(File.join(project, "tmp/references/fake/Fake.xcodeproj"))
  FileUtils.mkdir_p(File.join(project, "tmp/references/fake/android"))

  File.write(File.join(project, "Gemfile.lock"), <<~LOCK)
    GEM
      specs:
        rails (8.1.3)
        turbo-rails (2.0.23)
  LOCK
  File.write(File.join(project, "package.json"), JSON.generate(
    "dependencies" => {
      "@hotwired/hotwire-native-bridge" => "1.2.2",
      "@hotwired/stimulus" => "3.2.2"
    }
  ))
  File.write(File.join(project, "app/controllers/application_controller.rb"), "hotwire_native_app?\n")
  File.write(File.join(project, "config/routes.rb"), <<~ROUTES)
    Rails.application.routes.draw do
      resources :configurations, only: [] do
        get "ios_v1", on: :collection
        get "android_v1", on: :collection
      end
    end
  ROUTES
  File.write(File.join(project, "app/controllers/configurations_controller.rb"), <<~RUBY)
    class ConfigurationsController < ApplicationController
      def ios_v1
        render json: {
          settings: {},
          rules: []
        }
      end

      def android_v1
        render action: "android_v1"
      end
    end
  RUBY
  File.write(File.join(project, "app/views/configurations/android_v1.json.erb"), <<~JSON)
    {
      "settings": {},
      "rules": []
    }
  JSON
  File.write(File.join(project, "app/javascript/controllers/bridge/form_controller.js"), "static component = \"form\"\n")
  File.write(File.join(project, "config/ios_v1.json"), '{"settings":{},"rules":[]}')
  File.write(File.join(project, "ios/App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"), JSON.generate(
    "pins" => [
      {
        "identity" => "hotwire-native-ios",
        "location" => "https://github.com/hotwired/hotwire-native-ios.git",
        "state" => { "version" => "1.3.0", "revision" => "example" }
      }
    ],
    "version" => 2
  ))
  File.write(File.join(project, "android/settings.gradle.kts"), "rootProject.name = \"App\"\n")
  File.write(File.join(project, "android/app/build.gradle.kts"), 'implementation("dev.hotwire:core:1.3.0")')
  File.write(File.join(project, "tmp/references/fake/android/settings.gradle.kts"), "rootProject.name = \"ReferenceOnly\"\n")

  stdout, = run_command(RUBY, project_auditor, "--root", project, "--json")
  audit = JSON.parse(stdout)
  raise "Rails version audit failed" unless audit.dig("rails", "rails") == "8.1.3"
  raise "iOS version audit failed" unless audit.dig("ios", "resolved_dependencies", 0, "version") == "1.3.0"
  raise "Android version audit failed" unless audit.dig("android", "resolved_dependencies", 0, "version") == "1.3.0"
  raise "Ignored reference iOS project leaked into audit" unless audit.dig("ios", "xcode_projects") == ["ios/App.xcodeproj"]
  raise "Ignored reference Android project leaked into audit" unless audit.dig("android", "gradle_projects") == ["android/settings.gradle.kts"]
  raise "Schema-shaped path configuration file was not detected" unless audit.dig("integration", "path_configurations").include?("config/ios_v1.json")

  rails_path_configuration = audit.dig("integration", "rails_path_configuration")
  raise "Rails endpoint candidate was not detected" unless rails_path_configuration["endpoint_candidate"]
  raise "Static audit must not claim runtime verification" unless rails_path_configuration["runtime_verified"] == false

  evidence = rails_path_configuration["evidence"]
  raise "Rails route evidence was not reported" unless evidence.any? { |item| item["kind"] == "rails_route" && item["file"] == "config/routes.rb" }
  raise "Controller-rendered configuration was not reported" unless evidence.any? { |item| item["kind"] == "rails_controller" && item["file"] == "app/controllers/configurations_controller.rb" }
  raise "Server-rendered configuration view was not reported" unless evidence.any? { |item| item["kind"] == "rails_view" && item["file"] == "app/views/configurations/android_v1.json.erb" }
  raise "Static endpoint warning was not reported" unless audit["warnings"].any? { |warning| warning.include?("static inspection only") }

  unrelated = File.join(tmp, "unrelated")
  FileUtils.mkdir_p(File.join(unrelated, "config"))
  FileUtils.mkdir_p(File.join(unrelated, "app/controllers"))
  File.write(File.join(unrelated, "config/routes.rb"), <<~ROUTES)
    Rails.application.routes.draw do
      resources :configurations, only: :show
    end
  ROUTES
  File.write(File.join(unrelated, "app/controllers/configurations_controller.rb"), <<~RUBY)
    class ConfigurationsController < ApplicationController
      def show
        render json: { settings: current_user.settings }
      end
    end
  RUBY

  stdout, = run_command(RUBY, project_auditor, "--root", unrelated, "--json")
  unrelated_audit = JSON.parse(stdout)
  raise "Generic configurations endpoint was misclassified" if unrelated_audit.dig("integration", "rails_path_configuration", "endpoint_candidate")
  raise "Generic route was misreported as path-configuration evidence" unless unrelated_audit.dig("integration", "rails_path_configuration", "evidence").empty?
end

puts "All Hotwire Native Skill script tests passed."
