# frozen_string_literal: true

module ESPHome
  module Entities
    class Switch < Entity
      include HasDeviceClass
      include HasAssumedState
      include HasState

      def update(state_response)
        @state = state_response.state
      end
    end
  end
end
