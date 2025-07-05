# frozen_string_literal: true

module ESPHome
  module Cli
    module Colors
      ANSI_COLOR_MAP = {
        30 => Curses::COLOR_BLACK,
        31 => Curses::COLOR_RED,
        32 => Curses::COLOR_GREEN,
        33 => Curses::COLOR_YELLOW,
        34 => Curses::COLOR_BLUE,
        35 => Curses::COLOR_MAGENTA,
        36 => Curses::COLOR_CYAN,
        37 => Curses::COLOR_WHITE
      }.freeze

      # Regex to match ANSI color codes (like \e[31m)
      ANSI_ESCAPE_REGEX = /\e\[(\d+(?:;\d+)*)m/

      private

      def parse_sgr_codes(codes)
        color = nil
        attr = Curses::A_NORMAL

        codes.each do |code|
          code = code.to_i
          if ANSI_COLOR_MAP.key?(code)
            color = ANSI_COLOR_MAP[code]
          elsif code == 1
            attr |= Curses::A_BOLD
          elsif code == 4
            attr |= Curses::A_UNDERLINE
          elsif code.zero?
            attr = Curses::A_NORMAL
            color = nil
          end
        end

        [color, attr]
      end
    end
  end
end
