# frozen_string_literal: true

require_relative "form"

module ESPHome
  module Cli
    module Entities
      class Number < Form
        def length_range
          max_length = range&.end ? range.end.to_s.length : 10
          max_length += accuracy_decimals + 1 if accuracy_decimals.positive?
          1..max_length
        end

        def suffix
          unit_of_measurement
        end

        def activate
          @field.set_buffer(0, format("%.#{accuracy_decimals}f", state)) if state
          super
        end

        def command(value)
          begin
            value = Float(value)
          rescue ArgumentError
            cli.error("Invalid number: #{value}")
            return
          end

          cli.info("Setting #{object_id_} to #{formatted_state(value)}")
          set(value)
        end
      end
    end
  end
end
