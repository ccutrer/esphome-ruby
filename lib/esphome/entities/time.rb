# frozen_string_literal: true

module ESPHome
  module Entities
    class Date < Entity
      include HasState

      def update(state_response)
        @state = if state_response.missing_state
                   nil
                 elsif defined?(ActiveSupport::Duration)
                   state_response.hour.hours +
                     state_response.minute.minutes +
                     state_response.second.seconds
                 else
                   [state_response.hour, state_response.minute, state_response.second]
                 end
      end

      def formatted_state
        return format("%02d:%02d:%02d", *state) if state.is_a?(Array)

        super
      end

      def command(state)
        if defined?(ActiveSupport::Duration)
          parts = state.parts
          device.send(Api::TimeCommandRequest.new(key:,
                                                  hour: parts[:hours] || 0,
                                                  minute: parts[:minutes] || 0,
                                                  second: parts[:seconds] || 0))
        else
          device.send(Api::TimeCommandRequest.new(key:, hour: state[0], minute: state[1], second: state[2]))
        end
      end
    end
  end
end
