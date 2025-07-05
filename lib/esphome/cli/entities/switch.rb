# frozen_string_literal: true

require_relative "menu"

module ESPHome
  module Cli
    module Entities
      class Switch < Menu
        def options = %w[on off]

        def command(command)
          cli.log("Turning #{object_id_} #{command}")
          __send__(command.to_sym)
        end
      end
    end
  end
end
