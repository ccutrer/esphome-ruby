# frozen_string_literal: true

require_relative "form"

module ESPHome
  module Cli
    module Entities
      class Date < Form
        def length_range
          3..11
        end

        def command(value)
          begin
            value = Date.parse(value)
          rescue ArgumentError
            cli.error("Invalid date: #{value}")
            return
          end

          cli.info("Setting #{object_id_} to #{value.iso8601}")
          super
        end
      end
    end
  end
end
