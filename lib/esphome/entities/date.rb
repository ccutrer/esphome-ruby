# frozen_string_literal: true

module ESPHome
  module Entities
    class Date < Entity
      include HasState

      def update(state_response)
        @state = if state_response.missing_state
                   nil
                 else
                   Date.new(state_response.year,
                            date_response.month,
                            date_response.day)
                 end
      end

      def command(state)
        device.send(Api::DateCommandRequest.new(key:, year: state.year, month: state.month, day: state.day))
      end
    end
  end
end
