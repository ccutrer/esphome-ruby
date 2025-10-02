# frozen_string_literal: true

require_relative "menu"

module ESPHome
  module Cli
    module Entities
      class Lock < Menu
        def options
          supports_open? ? %w[lock unlock open] : %w[lock unlock]
        end

        def command(command)
          cli.info("#{command}ing #{object_id_}")
          super
        end
      end
    end
  end
end
