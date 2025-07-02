# frozen_string_literal: true

require "noise"
require "socket"

require_relative "api"

module ESPHome
  class Device
    NOISE_PROTOCOL = "Noise_NNpsk0_25519_ChaChaPoly_SHA256"
    NOISE_PROLOGUE = "NoiseAPIInit\0\0"
    PROTOCOL_PLAINTEXT = 0
    PROTOCOL_ENCRYPTED = 1
    API_VERSION_MAJOR = 1
    API_VERSION_MINOR = 9
    private_constant :NOISE_PROTOCOL,
                     :NOISE_PROLOGUE,
                     :PROTOCOL_PLAINTEXT,
                     :PROTOCOL_ENCRYPTED,
                     :API_VERSION_MAJOR,
                     :API_VERSION_MINOR

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
    attr_accessor :logger

    def initialize(address, encryption_key, port: 6053, logger: nil)
      @address = address
      @encryption_key = encryption_key.unpack1("m0")
      @port = port
      @socket = nil
      @logger = logger || Logger.new($stdout)
      @noise = nil
      @on_message_callback = nil
      @entities = nil
    end

    def connect
      @socket = TCPSocket.new(address, port)
      begin
        # Noise logs warnings about not being able to load algorithms we don't even care about.
        old_level = Noise.logger.level
        Noise.logger.level = Logger::ERROR
        @noise = Noise::Connection::Initiator.new(NOISE_PROTOCOL)
      ensure
        Noise.logger.level = old_level
      end
      @noise.psks = [@encryption_key]
      @noise.prologue = NOISE_PROLOGUE
      @noise.start_handshake

      write_frame("")

      _device_id = read_frame

      write_frame("\0#{@noise.write_message}")
      @noise.read_message(read_frame[1..])

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
    end

    def entities
      return @entities if @entities

      send(Api::ListEntitiesRequest.new)

      @entities = {}
      Kernel.loop do
        message = read_message
        break if message.is_a?(Api::ListEntitiesDoneResponse)

        unless message.class.respond_to?(:entity_class)
          logger.warn("Unrecognized entity #{message.inspect}")
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
        message = read_message

        if message.is_a?(Api::PingRequest)
          send(Api::PingResponse.new)
          next
        end

        if message.respond_to?(:key) && (entity = @entities[message.key])
          entity.update(message)
          @on_message_callback&.call(entity)
        elsif message.is_a?(Api::SubscribeLogsResponse)
          @on_message_callback&.call(message.message)
        else
          @on_message_callback&.call(message)
        end
      end
    rescue Interrupt
      nil
    end

    def on_message(&block)
      @on_message_callback = block
    end

    def send(message)
      logger.debug { "> #{message.inspect}" }
      serialized_message = message.to_proto
      unencrypted_message = [message.class.descriptor.id,
                             serialized_message.length,
                             serialized_message].pack("nnA*")
      encrypted_message = @noise.encrypt(unencrypted_message)
      write_frame(encrypted_message)
    end

    private

    def write_frame(data)
      @socket.write([PROTOCOL_ENCRYPTED, data.length, data].pack("cnA*"))
    end

    def read_frame
      header = @socket.read(3)
      raise "No data" if header.nil?

      type, length = header.unpack("cn")
      raise "Plaintext protocol not supported" if type == PROTOCOL_PLAINTEXT
      raise "Unrecognized protocol #{type}" unless type == PROTOCOL_ENCRYPTED

      @socket.read(length)
    end

    def read_message
      encrypted_message = read_frame
      decrypted_message = @noise.decrypt(encrypted_message)
      id, _length, encoded_message = decrypted_message.unpack("nnA*")
      klass = Api::ID_TO_MESSAGE[id]
      raise "Unrecognized message id #{id}" unless klass

      klass.decode(encoded_message).tap do |message|
        logger.debug { "< #{message.inspect}" }
      end
    end
  end
end
