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

      def command(state)
        device.send(Api::SwitchCommandRequest.new(key:, state:))
      end

      def formatted_state = state ? "on" : "off"

      def on = command(true)
      def off = command(false)
    end
  end
end
