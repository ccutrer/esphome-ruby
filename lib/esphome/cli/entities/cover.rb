# frozen_string_literal: true

require_relative "menu"

module ESPHome
  module Cli
    module Entities
      class Cover < Menu
        VERBS = {
          open: "Opening",
          close: "Closing",
          stop: "Stopping"
        }.freeze
        private_constant :VERBS
        def options
          %w[open close stop]
        end

        def command(value)
          value = value.to_sym
          cli.info("#{VERBS[value]} #{object_id_}")
          __send__(value)
        end
      end
    end
  end
end
