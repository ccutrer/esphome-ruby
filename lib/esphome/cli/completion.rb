# frozen_string_literal: true

require "shellwords"
require "uri"

require "esphome/dashboard"

module ESPHome
  module Cli
    module Completion
      class << self
        def run(prefix: ARGV[1].to_s,
                comp_line: ENV["COMP_LINE"],
                multi: false)
          argv = Shellwords.split(comp_line || "")[1..]
          dashboard_uri, argv = extract_dashboard_uri(argv)
          return if argv.length > 1 && !multi

          dashboard = ESPHome::Dashboard.new(dashboard_uri)
          puts dashboard.devices
                        .filter_map { |device| device["name"] }
                        .select { |name| name.start_with?(prefix) }
                        .sort
        rescue HTTPX::Error, IOError, SocketError, SystemCallError, Timeout::Error
          nil
        end

        private

        def extract_dashboard_uri(argv)
          argv ||= []
          dashboard_uri = Dashboard::DEFAULT_URI
          if argv[0]
            uri = URI.parse(argv[0])
            if uri.scheme
              dashboard_uri = uri.to_s
              argv = argv[1..]
            end
          end

          [dashboard_uri, argv]
        rescue URI::InvalidURIError
          [dashboard_uri, argv]
        end
      end
    end
  end
end
