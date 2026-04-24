# frozen_string_literal: true

require "fileutils"
require "securerandom"
require "socket"
require "tmpdir"

module ESPHome
  class HostDevice
    class Error < StandardError
      attr_reader :output

      def initialize(message, output)
        @output = output

        super(message)
      end
    end

    class ConfigError < Error; end
    class CompileError < Error; end
    class StartError < Error; end

    DEFAULT_START_TIMEOUT = 300
    DEFAULT_STOP_TIMEOUT = 10
    DEFAULT_CONNECT_INTERVAL = 0.25

    attr_reader :device, :config_path, :encryption_key, :port, :log_level, :emulator_output

    def initialize(yaml = nil, start_timeout: DEFAULT_START_TIMEOUT, log_level: :DEBUG)
      @yaml = yaml
      @start_timeout = start_timeout
      @dir = nil
      @config_path = nil
      @port = nil
      @encryption_key = [SecureRandom.random_bytes(32)].pack("m0")
      @pid = nil
      @exit_status = nil
      @reader_thread = nil
      @loop_thread = nil
      @emulator_output = +""
      @log_level = log_level
      @logs = []
      @logs_mutex = Mutex.new
      @logs_condition = ConditionVariable.new
      @device = nil
    end

    def start
      @dir = Dir.mktmpdir("esphome-ruby-spec-")
      @port = available_port
      @config_path = File.join(@dir, "device.yaml")
      File.write(@config_path, config_yaml)

      read_pipe, write_pipe = IO.pipe
      @pid = Process.spawn(
        "esphome",
        "run",
        @config_path,
        "--no-logs",
        out: write_pipe,
        err: write_pipe,
        pgroup: true
      )
      write_pipe.close
      @reader_thread = Thread.new do
        read_pipe.each_line do |line|
          @emulator_output << line
        end
      ensure
        read_pipe.close
      end

      connect
      self
    rescue
      stop
      raise
    end

    def stop
      @device&.disconnect if @device&.connected?
    rescue
      nil
    ensure
      @loop_thread&.join(1)
      stop_process
      @reader_thread&.join(1)
      FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
    end

    def logs
      @logs_mutex.synchronize { @logs.dup }
    end

    def log(_severity, message)
      @logs_mutex.synchronize do
        @logs << message
        @logs_condition.broadcast
      end
    end

    def wait_for_log_line(pattern, timeout: 1)
      deadline = monotonic_time + timeout

      @logs_mutex.synchronize do
        loop do
          current_logs = @logs.dup
          return current_logs if log_line_matches?(current_logs, pattern)

          remaining = deadline - monotonic_time
          break if remaining <= 0

          @logs_condition.wait(@logs_mutex, remaining)
        end
      end

      raise Timeout::Error, "Timed out waiting for #{pattern.inspect} in ESPHome API log:\n\n#{logs.join("\n")}"
    end

    private

    def config_yaml
      <<~YAML
        esphome:
          name: esphome-ruby-spec
          friendly_name: ESPHome Ruby Spec

        host:

        logger:
          level: #{log_level}

        api:
          port: #{port}
          encryption:
            key: #{encryption_key}

        #{@yaml}
      YAML
    end

    def connect
      deadline = monotonic_time + @start_timeout
      last_error = nil

      until monotonic_time >= deadline
        raise exited_error unless process_running?

        begin
          @device = ESPHome::Device.new("127.0.0.1", encryption_key, port:)
          @device.connect_timeout = 1
          @device.read_timeout = 1
          @device.device_logger = self
          @device.connect
          @device.stream_log(:very_verbose)
          # need to make sure entities are cached before we start the background loop thread
          @device.entities
          @loop_thread = Thread.new do
            @device.loop
          rescue IOError, ConnectionClosedError
            nil
          end
          return
        rescue => e
          last_error = e
          @device&.__send__(:disconnected)
          sleep DEFAULT_CONNECT_INTERVAL
        end
      end

      raise StartError.new("Timed out connecting to ESPHome emulator: #{last_error&.message}", logs)
    end

    def stop_process
      return unless @pid
      return if @exit_status

      return if Process.wait(@pid, Process::WNOHANG)

      signal_process("TERM")
      deadline = monotonic_time + DEFAULT_STOP_TIMEOUT
      sleep DEFAULT_CONNECT_INTERVAL until monotonic_time >= deadline || !process_running?

      signal_process("KILL") if process_running?
      Process.wait(@pid)
    rescue Errno::ECHILD
      nil
    ensure
      @pid = nil
    end

    def signal_process(signal)
      Process.kill(signal, -@pid)
    rescue Errno::ESRCH
      nil
    end

    def process_running?
      return false unless @pid
      return false if @exit_status

      @exit_status = Process.wait(@pid, Process::WNOHANG)
      return false if @exit_status

      Process.kill(0, @pid)
      true
    rescue Errno::ESRCH
      false
    end

    def available_port
      server = TCPServer.new("127.0.0.1", 0)
      server.addr[1]
    ensure
      server&.close
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def log_line_matches?(current_logs, pattern)
      current_logs.any? do |message|
        pattern.is_a?(Regexp) ? message.match?(pattern) : message.include?(pattern)
      end
    end

    def exited_error
      @reader_thread&.join(1)

      output = emulator_output
      error_class =
        if output.match?(/Invalid YAML syntax|Failed config|Error while reading config/i)
          ConfigError
        elsif output.match?(/Compiling app|Linking|error:|undefined reference|FAILED/i)
          CompileError
        else
          StartError
        end

      error_class.new(nil, output)
    end
  end
end
