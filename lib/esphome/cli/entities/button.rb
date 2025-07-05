# frozen_string_literal: true

module ESPHome
  module Cli
    module Entities
      class Button < Entity
        def formatted_state
          "PRESS"
        end

        def activate
          cli.log("Pressing #{object_id_}")
          press
        end
      end
    end
  end
end
