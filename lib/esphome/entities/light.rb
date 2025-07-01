# frozen_string_literal: true

module ESPHome
  module Entities
    class Light < Entity
      include HasState

      attr_reader :supported_color_modes,
                  :mireds_range,
                  :effects,
                  :brightness,
                  :color_mode,
                  :color_brightness,
                  :color_temperature,
                  :red,
                  :green,
                  :blue,
                  :white,
                  :cold_white,
                  :warm_white,
                  :transition_length,
                  :flash_effect,
                  :effect

      def initialize(_device, list_entities_response)
        super

        @supported_color_modes = list_entities_response.supported_color_modes.map { |mode| mode[11..].downcase.to_sym }
        if @supported_color_modes.empty?
          @supported_color_modes << :brightness if list_entities_response.legacy_supports_brightness
          @supported_color_modes << :rgb if list_entities_response.legacy_supports_rgb
          @supported_color_modes << :white if list_entities_response.legacy_supports_white
          @supported_color_modes << :color_temperature if list_entities_response.legacy_supports_color_temperature
          @supported_color_modes = [:on_off] if @supported_color_modes.empty?
        end
        @supported_color_modes = @supported_color_modes.to_set { |mode| transform_color_mode(mode) }.freeze

        @mireds_range = Range.new(list_entities_response.min_mireds, list_entities_response.max_mireds)

        @effects = list_entities_response.effects.map(&:freeze).freeze

        @brightness = @color_temperature = @red = @green = @blue = @white = @cold_white = @warm_white = nil
      end

      def brightness?
        @supported_color_modes.include?(:brightness)
      end

      def white?
        @supported_color_modes.intersect?(%i[white ww rgbw rgbww])
      end

      def rgb?
        @supported_color_modes.intersect?(%i[rgb rgbw rgb_color_temperature rgbww])
      end

      def color_temperature?
        @supported_color_modes.intersect?(%i[color_temperature rgb_color_temperature])
      end

      def ww?
        @supported_color_modes.intersect?(%i[ww rgbww])
      end

      def update(state_response)
        @state = state_response.state
        @brightness = state_response.brightness if brightness?
        @color_mode = state_response.color_mode
        if rgb?
          @color_brightness = state_response.color_brightness
          @red = state_response.red
          @green = state_response.green
          @blue = state_response.blue
        end
        @white = state_response.white if white?
        @color_temperature = state_response.color_temperature if color_temperature?
        if ww?
          @cold_white = state_response.cold_white
          @warm_white = state_response.warm_white
        end
        @effect = state_response.effect.empty? ? nil : state_response.effect
      end

      def formatted_state
        result = case state
                 when nil then "-"
                 when true then "on"
                 else "off"
                 end
        result += " #{brightness || color_brightness || "-"}%" if brightness?

        if effect
          result += effect
        else
          result += " #{color_temperature || "-"} mired" if color_temperature?

          color = []
          color.push(red, green, blue) if rgb?
          color.push(white) if white?
          color.push(cold_white, warm_white) if ww?
          result += " (#{color.map { |c| c || "-" }.join(",")})" unless color.empty?
        end

        result += " @ #{transition_length} ms" if transition_length
        result += " (flash)" if flash_effect

        result
      end

      private

      def transform_color_mode(mode)
        case mode
        when :cold_warm_white then :ww
        when :rgb_white then :rgbw
        when :rgb_cold_warm_white then :rgbww
        else mode
        end
      end

      def inspection_vars
        super + %i[supported_color_modes
                   mireds_range
                   effects
                   brightness
                   color_mode
                   color_brightness
                   color_temperature
                   red
                   green
                   blue
                   white
                   cold_white
                   warm_white
                   transition_length
                   flash_effect
                   effect]
      end

      def hideable?(var, val)
        super ||
          (var == :supported_color_modes && supported_color_modes.size <= 1) ||
          (var == :mireds_range && !color_temperature?) ||
          (var == :effects && effects.empty?) ||
          (var == :brightness && !brightness?) ||
          (var == :color_mode && supported_color_modes.size <= 1) ||
          (var == :color_brightness && !brightness? && !rgb?) ||
          (var == :color_temperature && !color_temperature?) ||
          (%i[red green blue].include?(var) && !rgb?) ||
          (var == :white && !white?) ||
          (%(cold_white warm_white).include?(var) && !ww?) ||
          (var == :transition_length && !transition_length) ||
          (var == :flash_effect && !flash_effect) ||
          (var == :effect && effects.empty?)
      end
    end
  end
end
