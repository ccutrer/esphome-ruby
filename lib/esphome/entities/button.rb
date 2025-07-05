# frozen_string_literal: true

module ESPHome
  module Entities
    class Button < Entity
      include HasDeviceClass

      def press
        device.send(Api::ButtonCommandRequest.new(key:))
      end
    end
  end
end
