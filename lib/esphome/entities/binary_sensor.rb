# frozen_string_literal: true

module ESPHome
  module Entities
    class BinarySensor < Entity
      DEVICE_CLASSES = Hash.new({ true => "on", false => "off" }.freeze).merge(
        "battery" => { true => "low", false => "normal" }.freeze,
        "battery_charging" => { true => "charging", false => "not charging" }.freeze,
        "carbon_monoxide" => { true => "detected", false => "clear" }.freeze,
        "cold" => { true => "cold", false => "normal" }.freeze,
        "connectivity" => { true => "connected", false => "disconnected" }.freeze,
        "door" => { true => "open", false => "closed" }.freeze,
        "garage_door" => { true => "open", false => "closed" }.freeze,
        "gas" => { true => "detected", false => "clear" }.freeze,
        "heat" => { true => "hot", false => "normal" }.freeze,
        "light" => { true => "detected", false => "not detected" }.freeze,
        "lock" => { true => "locked", false => "unlocked" }.freeze,
        "moisture" => { true => "wet", false => "dry" }.freeze,
        "motion" => { true => "detected", false => "clear" }.freeze,
        "moving" => { true => "moving", false => "stopped" }.freeze,
        "occupancy" => { true => "occupied", false => "not occupied" }.freeze,
        "opening" => { true => "open", false => "closed" }.freeze,
        "plug" => { true => "plugged in", false => "unplugged" }.freeze,
        "power" => { true => "detected", false => "no power" }.freeze,
        "presence" => { true => "home", false => "away" }.freeze,
        "problem" => { true => "problem", false => "ok" }.freeze,
        "running" => { true => "running", false => "not running" }.freeze,
        "safety" => { true => "unsafe", false => "safe" }.freeze,
        "smoke" => { true => "detected", false => "clear" }.freeze,
        "sound" => { true => "detected", false => "not detected" }.freeze,
        "tamper" => { true => "tampered", false => "clear" }.freeze,
        "update" => { true => "available", false => "up-to-date" }.freeze,
        "vibration" => { true => "detected", false => "clear" }.freeze,
        "window" => { true => "open", false => "closed" }.freeze
      ).freeze

      include HasDeviceClass
      include HasState

      def initialize(_device, list_entities_response)
        super
        @status = list_entities_response.is_status_binary_sensor
      end

      def status?
        @status
      end

      def formatted_state
        return super if state.nil?

        DEVICE_CLASSES[device_class][state]
      end

      private

      def inspection_vars
        super + [:status?]
      end

      def hideable?(var, val)
        super || (var == :status? && !val)
      end
    end
  end
end
