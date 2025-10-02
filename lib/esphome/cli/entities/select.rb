# frozen_string_literal: true

require_relative "menu"

module ESPHome
  module Cli
    module Entities
      class Select < Menu
        def command(value)
          cli.info("Setting #{object_id_} to #{value}")
          super
        end
      end
    end
  end
end
