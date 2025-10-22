# frozen_string_literal: true

module WebSocket
  class Driver
    # WebSocket driver with HTTPX handling the HTTP negotiation
    class HTTPX < Hybi
      def initialize(socket, headers, options = {})
        super(socket, options)
        @headers = headers
        @closed = false

        @key = Client.generate_key
        @accept = Driver::Hybi.generate_accept(@key)

        @headers["upgrade"]               = "websocket"
        @headers["connection"]            = "Upgrade"
        @headers["sec-websocket-key"]     = @key
        @headers["sec-websocket-version"] = VERSION

        @headers["Sec-WebSocket-Protocol"] = @protocols * ", " if @protocols.size.positive?

        extensions = @extensions.generate_offer
        @headers["Sec-WebSocket-Extensions"] = extensions if extensions
      end

      def start
        open
        parse(@initial_response)
      end

      def run
        closed = false
        on(:close) do
          closed = true
        end

        until closed
          bytes = @socket.read(1)
          parse(bytes)
        end
      end

      private

      def fail_handshake(message) # rubocop:disable Naming/PredicateMethod
        message = "Error during WebSocket handshake: #{message}"
        @ready_state = 3
        emit(:error, message)
        emit(:close, Driver::CloseEvent.new(Driver::Hybi::ERRORS[:protocol_error], message))
        false
      end

      def validate_handshake(headers)
        accept     = headers["sec-websocket-accept"]
        protocol   = headers["sec-websocket-protocol"]

        return fail_handshake("Sec-WebSocket-Accept mismatch") unless accept == @accept

        if protocol && !protocol.empty?
          return fail_handshake("Sec-WebSocket-Protocol mismatch") unless @protocols.include?(protocol)

          @protocol = protocol
        end

        begin
          @extensions.activate(@headers["Sec-WebSocket-Extensions"])
        rescue ::WebSocket::Extensions::ExtensionError => e
          return fail_handshake(e.message)
        end
        true
      end
    end
  end
end
