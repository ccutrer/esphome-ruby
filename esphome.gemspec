# frozen_string_literal: true

require_relative "lib/esphome/version"

Gem::Specification.new do |spec|
  spec.name = "esphome"
  spec.version = ESPHome::VERSION
  spec.authors = ["Cody Cutrer"]
  spec.email = ["cody@cutrer.us"]

  spec.summary = "ESPHome Library and CLI for Ruby"
  spec.homepage = "https://github.com/ccutrer/esphome-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["{exe|lib}/**/*"]
  spec.bindir = "exe"
  spec.executables = %w[esphome-monitor esphome-update-all]
  spec.require_paths = ["lib"]

  spec.add_dependency "curses", "~> 1.5"
  spec.add_dependency "google-protobuf", "~> 4.31"
  spec.add_dependency "httpx", "~> 1.5"
  spec.add_dependency "logger", "~> 1.7"
  spec.add_dependency "noise-ruby", "~> 0.10"
  spec.add_dependency "websocket-driver", "~> 0.8"
end
