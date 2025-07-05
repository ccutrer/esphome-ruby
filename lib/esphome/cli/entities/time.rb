# frozen_string_literal: true

require_relative "form"

module ESPHome
  module Cli
    module Entities
      class Time < Form
        def length_range
          25..25
        end

        def command(value)
          if defined?(ActiveSupport::Duration)
            begin
              value = ActiveSupport::Duration.parse(value)
            rescue ArgumentError
              # ignore; try to parse another way
            end
          end

          begin
            if value.is_a?(String)
              value = value.split(":").map { |v| Integer(v) }
              raise ArgumentError if value.length > 3

              value.unshift(0) while value.length < 3
            end
          rescue ArgumentError
            cli.log("Invalid time: #{value}")
            return
          end

          cli.log("Setting #{object_id_} to #{value.iso8601}")
          super
        end
      end
    end
  end
end
