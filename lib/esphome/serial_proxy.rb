# frozen_string_literal: true

require "timeout"

module ESPHome
  class SerialProxy
    class WaitReadable < RuntimeError
      include ::IO::WaitReadable
    end

    attr_reader :device,
                :name,
                :instance,
                :port_type,
                :baud,
                :data_bits,
                :parity,
                :stop_bits

    class << self
      def open(address, encryption_key, instance = nil, **kwargs)
        device = Device.new(address, encryption_key)
        device.connect

        instance ||= 0
        io = device.serial_proxies[instance]
        begin
          io ||= device.serial_proxies[Integer(instance)]
        rescue ArgumentError
          # ignore; will raise below anyway
        end

        raise NoSuchSerialProxyError, "No serial proxy #{instance.inspect}" unless io

        io.set_modem_params(**kwargs) unless kwargs.empty?
        loop_thread = io.instance_variable_set(:@loop_thread, Thread.new do
          device.loop
        end)
        io.open

        if block_given?
          begin
            yield io
          ensure
            io.close
            device.disconnect
            loop_thread.join
          end
          nil
        else
          io
        end
      end
    end

    # @!visibility private
    def initialize(device, name, instance, port_type)
      @device = device
      @name = name
      @instance = instance
      @port_type = port_type
      @buffer = "".b
      @mutex = Mutex.new
      @data_ready = ConditionVariable.new
      @request_mutex = Mutex.new
      @closed = true
      @baud = nil
      @data_bits = nil
      @parity = nil
      @stop_bits = nil
      @queue = Queue.new

      @on_connect_callback = device.on_connect do
        open unless closed?
      end

      @on_disconnect_callback = device.on_disconnect do
        @queue << nil
        @mutex.synchronize do
          @data_ready.broadcast
        end
      end

      @on_message_callback = device.on_message do |message|
        case message
        when Api::SerialProxyDataReceived
          next unless message.instance == instance

          @mutex.synchronize do
            next if @closed

            @buffer << message.data.b
            @data_ready.broadcast
          end
        when Api::SerialProxyRequestResponse
          next unless message.instance == instance

          @queue << message
        end
      end
    end

    def set_modem_params(baud: nil, data_bits: nil, parity: nil, stop_bits: nil)
      raise ArgumentError, "Parity must be :none, :even, or :odd" if !parity.nil? && !%i[none even odd].include?(parity)
      raise MissingProxyError unless device

      current_baud = nil
      current_data_bits = nil
      current_parity = nil
      current_stop_bits = nil
      @mutex.synchronize do
        @baud = baud || @baud || 115_200
        @data_bits = data_bits || @data_bits || 8
        @parity = parity || @parity || :none
        @stop_bits = stop_bits || @stop_bits || 1
        current_baud = @baud
        current_data_bits = @data_bits
        current_parity = @parity
        current_stop_bits = @stop_bits
      end

      return unless device.connected?

      device.send(Api::SerialProxyConfigureRequest.new(instance:,
                                                       baudrate: current_baud,
                                                       flow_control: false,
                                                       parity: normalize_serial_proxy_parity(current_parity),
                                                       stop_bits: current_stop_bits,
                                                       data_size: current_data_bits))
    end

    def open
      raise MissingProxyError unless device

      @request_mutex.synchronize do
        @mutex.synchronize do
          return self unless @closed

          @closed = false
          @data_ready.broadcast
        end

        return self unless device.connected?

        wait(:SERIAL_PROXY_REQUEST_TYPE_SUBSCRIBE) do
          device.send(Api::SerialProxyRequest.new(instance:,
                                                  type: :SERIAL_PROXY_REQUEST_TYPE_SUBSCRIBE))
        end
      end

      self
    rescue
      @mutex.synchronize do
        @closed = true
        @data_ready.broadcast
      end
      raise
    end

    def close
      loop_thread = @mutex.synchronize do
        already_closed = @closed
        @closed = true
        @data_ready.broadcast
        [already_closed, @loop_thread]
      end

      return if loop_thread.first

      # We're in a SerialProxy.open block; just close the connection without unsubscribing
      if loop_thread.last
        device&.disconnect
        loop_thread.last.join
        @mutex.synchronize do
          @loop_thread = nil
        end
        return
      end
      return unless device&.connected?

      @request_mutex.synchronize do
        return unless device&.connected?

        wait(:SERIAL_PROXY_REQUEST_TYPE_UNSUBSCRIBE) do
          device.send(Api::SerialProxyRequest.new(instance:,
                                                  type: :SERIAL_PROXY_REQUEST_TYPE_UNSUBSCRIBE))
        end
      end
    end

    def write(data)
      raise EOFError, "closed stream" if closed?
      raise MissingDeviceError unless device
      raise EOFError, "serial proxy disconnected" unless device.connected?

      encoded = String(data).b
      device.send(Api::SerialProxyWriteRequest.new(instance:, data: encoded))
      encoded.bytesize
    end

    def flush
      raise EOFError, "closed stream" if closed?
      raise MissingDeviceError unless device
      raise EOFError, "serial proxy disconnected" unless device.connected?

      @request_mutex.synchronize do
        wait(:SERIAL_PROXY_REQUEST_TYPE_FLUSH) do
          device.send(Api::SerialProxyRequest.new(instance:,
                                                  type: :SERIAL_PROXY_REQUEST_TYPE_FLUSH))
        end
      end
    end

    def read(length, outbuf = +"")
      readpartial(length, outbuf)
      outbuf.concat(readpartial(length - outbuf.bytesize)) while outbuf.bytesize < length
      outbuf
    end

    def readbyte
      read(1)&.getbyte(0)
    end
    alias_method :getbyte, :readbyte

    def readpartial(maxlen, outbuf = +"")
      raise ArgumentError, "maxlen must be non-negative" unless maxlen >= 0

      data = wait_for_data do
        raise EOFError if @closed && @buffer.empty?
        break +"".b if maxlen.zero?
        break @buffer.slice!(0, maxlen) unless @buffer.empty?
      end

      apply_outbuf(outbuf, data)
    end

    def read_nonblock(maxlen, outbuf = +"", options = {})
      raise ArgumentError, "maxlen must be non-negative" unless maxlen >= 0

      if outbuf == ({ exception: false })
        options = outbuf
        outbuf = +""
      end

      return apply_outbuf(outbuf, +"".b) if maxlen.zero?

      loop do
        data = @mutex.synchronize do
          raise EOFError if @closed && @buffer.empty?

          @buffer.slice!(0, maxlen) unless @buffer.empty?
        end
        return apply_outbuf(outbuf, data) if data

        result = wait_readable(0)
        if result.nil?
          raise WaitReadable unless options[:exception] == false

          return :wait_readable
        end

        next
      end
    end

    def wait_readable(timeout = nil)
      return self unless @buffer.empty?

      @mutex.synchronize do
        return self unless @buffer.empty?

        deadline = monotonic_time + timeout if timeout
        Kernel.loop do
          return nil if @closed || !device.connected?

          remaining = deadline && (deadline - monotonic_time)
          return nil if deadline && remaining <= 0

          @data_ready.wait(@mutex, remaining)
          return self unless @buffer.empty?
        end
      end
    end

    def ready?
      !wait_readable(0).nil?
    end

    def ungetbyte(byte)
      @mutex.synchronize do
        @buffer.insert(0, Integer(byte).chr)
        @data_ready.broadcast
      end
    end

    def ungetc(char)
      @mutex.synchronize do
        @buffer.insert(0, String(char))
        @data_ready.broadcast
      end
    end

    def closed?
      @mutex.synchronize { @closed }
    end

    private

    def normalize_serial_proxy_parity(parity)
      return parity if parity.to_s.start_with?("SERIAL_PROXY_PARITY_")

      :"SERIAL_PROXY_PARITY_#{parity.to_s.upcase}"
    end

    def wait(request_type)
      @queue.clear
      yield
      message = @queue.pop
      raise EOFError unless message

      unless message.type == request_type
        raise UnexpectedMessage,
              "Unexpected serial proxy response to request type #{message.type}"
      end

      case message.status
      when :SERIAL_PROXY_STATUS_OK, :SERIAL_PROXY_STATUS_ASSUMED_SUCCESS
        message.status
      when :SERIAL_PROXY_STATUS_TIMEOUT
        raise Timeout::Error
      when :SERIAL_PROXY_STATUS_NOT_SUPPORTED
        raise NotImplementedError
      when :SERIAL_PROXY_STATUS_ERROR
        raise SerialProxyError, message.error_message
      else
        raise SerialProxyError, "Unrecognized serial proxy status #{message.status.inspect}"
      end
    end

    def apply_outbuf(outbuf, data)
      return data unless outbuf

      outbuf.replace(data)
    end

    def wait_for_data
      @mutex.synchronize do
        Kernel.loop do
          raise EOFError if @closed

          result = yield
          return result unless result.nil?

          @data_ready.wait(@mutex)
        end
      end
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
