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

      def command(state)
        device.send(Api::DateTimeCommandRequest.new(key:, epoch_seconds: state.to_i))
      end
    end
  end
end
