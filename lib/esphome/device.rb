# frozen_string_literal: true

require "noise"
require "socket"
require "timeout"

require_relative "api"

module ESPHome
  class Device
    NOISE_PROTOCOL = "Noise_NNpsk0_25519_ChaChaPoly_SHA256"
    NOISE_PROLOGUE = "NoiseAPIInit\0\0"
    PROTOCOL_PLAINTEXT = 0
    PROTOCOL_ENCRYPTED = 1
    API_VERSION_MAJOR = 1
    API_VERSION_MINOR = 12

    LOG_LEVEL_MAP = Hash.new(Logger::UNKNOWN).merge(
      LOG_LEVEL_NONE: Logger::FATAL,
      LOG_LEVEL_ERROR: Logger::ERROR,
      LOG_LEVEL_WARN: Logger::WARN,
      LOG_LEVEL_INFO: Logger::INFO,
      LOG_LEVEL_CONFIG: Logger::INFO,
      LOG_LEVEL_DEBUG: Logger::DEBUG,
      LOG_LEVEL_VERBOSE: Logger::DEBUG,
      LOG_LEVEL_VERY_VERBOSE: Logger::DEBUG
    ).freeze

    private_constant :NOISE_PROTOCOL,
                     :NOISE_PROLOGUE,
                     :PROTOCOL_PLAINTEXT,
                     :PROTOCOL_ENCRYPTED,
                     :API_VERSION_MAJOR,
                     :API_VERSION_MINOR,
                     :LOG_LEVEL_MAP

    attr_reader :address,
                :port,
                :name,
                :mac_address,
                :esphome_version,
                :compilation_time,
                :model,
                :project_name,
                :project_version,
                :manufacturer,
                :friendly_name,
                :suggested_area
    attr_accessor :connection_logger, :device_logger, :connect_timeout, :read_timeout

    def initialize(address, encryption_key, port: 6053)
      @address = address
      @encryption_key = encryption_key.unpack1("m0")
      @port = port
      @socket = nil
      @connection_logger = nil
      @device_logger = nil
      @noise = nil
      @on_connect_callback = nil
      @on_disconnect_callback = nil
      @on_message_callback = nil
      @entities = nil
      @connect_timeout = 5
      @read_timeout = 5
    end

    def connect
      return if @socket

      @socket = TCPSocket.new(address, port, connect_timeout: @connect_timeout)
      begin
        # Noise logs warnings about not being able to load algorithms we don't even care about.
        old_level = Noise.logger.level
        Noise.logger.level = Logger::ERROR
        noise = Noise::Connection::Initiator.new(NOISE_PROTOCOL)
      ensure
        Noise.logger.level = old_level
      end
      noise.psks = [@encryption_key]
      noise.prologue = NOISE_PROLOGUE
      noise.start_handshake

      write_frame("")

      _device_id = read_frame

      write_frame("\0#{noise.write_message}")
      noise.read_message(read_frame[1..])
      @noise = noise

      send(Api::HelloRequest.new(client_info: "esphome-ruby",
                                 api_version_major: API_VERSION_MAJOR,
                                 api_version_minor: API_VERSION_MINOR))

      message = read_message

      raise "Unexpected message #{message.inspect}" unless message.is_a?(Api::HelloResponse)

      send(Api::ConnectRequest.new)

      message = read_message

      raise "Unexpected message #{message.inspect}" unless message.is_a?(Api::ConnectResponse)
      raise "Invalid password" if message.invalid_password

      send(Api::DeviceInfoRequest.new)

      message = read_message
      raise "Unexpected message #{message.inspect}" unless message.is_a?(Api::DeviceInfoResponse)

      @name = message.name
      @mac_address = message.mac_address
      @esphome_version = message.esphome_version
      @compilation_time = message.compilation_time
      @model = message.model
      @project_name = message.project_name
      @project_version = message.project_version
      @manufacturer = message.manufacturer
      @friendly_name = message.friendly_name
      @suggested_area = message.suggested_area

      @entities = nil

      @on_connect_callback&.call
    end

    def disconnect
      send(Api::DisconnectRequest.new) if @socket && @noise
    end

    def entities
      return @entities if @entities

      send(Api::ListEntitiesRequest.new)

      @entities = {}
      Kernel.loop do
        message = read_message
        break if message.is_a?(Api::ListEntitiesDoneResponse)

        unless message.class.respond_to?(:entity_class)
          connection_logger&.warn("Unrecognized entity #{message.inspect}")
          next
        end

        entity_class = message.class.entity_class
        @entities[message.key] = entity_class.new(self, message)
      end
      @entities.freeze
    end

    def stream_states
      send(Api::SubscribeStatesRequest.new)
    end

    def stream_log(level = :very_verbose, dump_config: false)
      request = Api::SubscribeLogsRequest.new(level: :"LOG_LEVEL_#{level.upcase}")
      request.dump_config = dump_config if dump_config
      send(request)
    end

    def loop
      Kernel.loop do
        message = nil
        begin
          message = read_message
        rescue Timeout::Error
          send(Api::PingRequest.new) if @noise
          next
        end

        if message.is_a?(Api::PingRequest)
          send(Api::PingResponse.new)
          next
        end

        if message.respond_to?(:key) && (entity = @entities[message.key])
          entity.update(message)
          @on_message_callback&.call(entity)
        elsif message.is_a?(Api::SubscribeLogsResponse)
          device_logger&.log(LOG_LEVEL_MAP[message.level], message.message)
        elsif message.is_a?(Api::DisconnectRequest)
          send(Api::DisconnectResponse.new)
          disconnected
          @on_message_callback&.call("Device disconnected")
          @on_disconnect_callback&.call
        elsif message.is_a?(Api::DisconnectResponse)
          disconnected
          @on_message_callback&.call("Disconnected")
        elsif message.is_a?(Api::PingResponse)
          # Nothing to do
        else
          @on_message_callback&.call(message)
        end
      end
    rescue Interrupt
      nil
    end

    %i[connect disconnect message].each do |callback|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def on_#{callback}(&block)          # def on_connect(&block)
          @on_#{callback}_callback = block  #   @on_connect_callback = block
          self                              #   self
        end                                 # end
      RUBY
    end

    def send(message)
      raise "Encryption not yet set up" unless @noise

      connection_logger&.debug { "> #{message.inspect}" }
      serialized_message = message.to_proto
      unencrypted_message = [message.class.descriptor.id,
                             serialized_message.length,
                             serialized_message].pack("nnA*")
      encrypted_message = @noise.encrypt(unencrypted_message)
      write_frame(encrypted_message)
    end

    private

    def disconnected
      @socket&.close
      @socket = nil
      @noise = nil
      @entities = nil
    end

    def write_frame(data)
      raise "Not connected" unless @socket

      @socket.write([PROTOCOL_ENCRYPTED, data.length, data].pack("cnA*"))
    rescue => e
      @on_message_callback&.call("Error writing to socket: #{e}")
      disconnected
      raise
    end

    def read_frame
      raise "Not connected" unless @socket

      @socket.wait_readable(@read_timeout) or raise Timeout::Error
      header = @socket.read(3)
      raise "No data" if header.nil?

      type, length = header.unpack("cn")
      raise "Plaintext protocol not supported" if type == PROTOCOL_PLAINTEXT
      raise "Unrecognized protocol #{type}" unless type == PROTOCOL_ENCRYPTED

      @socket.wait_readable(@read_timeout) or raise Timeout::Error
      @socket.read(length)
    rescue Timeout::Error
      raise
    rescue => e
      @on_message_callback&.call("Error reading from socket: #{e}")
      disconnected
      raise
    end

    def read_message
      encrypted_message = read_frame
      decrypted_message = @noise.decrypt(encrypted_message)
      id, length, encoded_message = decrypted_message.unpack("nna*")
      if length != encoded_message.length
        raise "Unexpected message length #{encoded_message.length}; expected #{length}"
      end

      klass = Api::ID_TO_MESSAGE[id]
      raise "Unrecognized message id #{id}" unless klass

      klass.decode(encoded_message).tap do |message|
        connection_logger&.debug { "< #{message.inspect}" }
      end
    end
  end
end
