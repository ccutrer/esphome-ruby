# frozen_string_literal: true

require "time"

require_relative "form"

module ESPHome
  module Cli
    module Entities
      class DateTime < Form
        def length_range
          25..25
        end

        def command(value)
          begin
            value = Time.parse(value)
          rescue ArgumentError
            cli.log("Invalid timestamp: #{value}")
            return
          end

          cli.log("Setting #{object_id_} to #{value.iso8601}")
          super
        end
      end
    end
  end
end
