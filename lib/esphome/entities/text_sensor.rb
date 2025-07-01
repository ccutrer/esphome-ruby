# frozen_string_literal: true

module ESPHome
  module Entities
    class TextSensor < Entity
      include HasDeviceClass
      include HasState
    end
  end
end
