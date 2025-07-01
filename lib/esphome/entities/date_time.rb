# frozen_string_literal: true

module ESPHome
  module Entities
    class DateTime < Entity
      include HasState

      def update(state_response)
        @state = if state_response.missing_state
                   nil
                 else
                   Time.at(state_response.epoch_seconds)
                 end
      end
    end
  end
end
