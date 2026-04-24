# frozen_string_literal: true

require "English"
require "fileutils"
require "securerandom"
require "socket"
require "tmpdir"
require "yaml"

module ESPHome
  class HostDevice
    class Error < StandardError; end
    class ConfigError < Error; end
    class CompileError < Error; end
    class StartError < Error; end

    DEFAULT_START_TIMEOUT = 5
    DEFAULT_STOP_TIMEOUT = 1
    DEFAULT_CONNECT_INTERVAL = 0.25

    attr_reader :device, :config_path, :encryption_key, :port, :log_level, :emulator_output

    def initialize(yaml = nil, start_timeout: DEFAULT_START_TIMEOUT, log_level: :DEBUG, tmp_directory: true)
      @yaml = yaml
      @start_timeout = start_timeout
      @tmp_directory = tmp_directory
      @config_directory = nil
      @config_path = "device.yaml"
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
      @updates_mutex = Mutex.new
      @updates_condition = ConditionVariable.new
      @device = nil
    end

    def start
      if @tmp_directory
        @config_directory = Dir.mktmpdir("esphome-ruby-spec-")
        @config_path = File.join(@config_directory, "device.yaml")
      end

      @port = available_port
      File.write(@config_path, config_yaml)

      read_pipe, write_pipe = IO.pipe
      pid = Process.spawn("esphome", "compile", @config_path, out: write_pipe, err: write_pipe, pgroup: true)
      write_pipe.close
      Process.wait(pid)
      raise CompileError, read_pipe.read unless $CHILD_STATUS.success?

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
      FileUtils.remove_entry(@config_directory) if @config_directory && File.directory?(@config_directory)
    end

    def logs
      @logs_mutex.synchronize { @logs.dup }
    end

    def log(_severity, message)
      @logs_mutex.synchronize do
        @logs << message
        @logs_condition.broadcast
      end
      signal_update
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

    def wait_until(timeout: 1, &)
      deadline = monotonic_time + timeout
      first_error = nil

      @updates_mutex.synchronize do
        loop do
          begin
            result = yield
          rescue Exception => e # rubocop:disable Lint/RescueException
            raise unless waitable_error?(e)

            first_error ||= e
            result = nil
          end
          return result if result

          remaining = deadline - monotonic_time
          break if remaining <= 0

          @updates_condition.wait(@updates_mutex, remaining)
        end
      end

      raise first_error if first_error

      raise Timeout::Error, "Timed out waiting for condition"
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
        unless process_running?
          @reader_thread.join(1)
          @reader_thread.kill
          @reader_thread.join
          raise StartError, emulator_output
        end

        begin
          @device = ESPHome::Device.new("127.0.0.1", encryption_key, port:)
          @device.connect_timeout = 1
          @device.read_timeout = 1
          @device.device_logger = self
          @device.on_message { signal_update }
          @device.connect
          @device.stream_log(:very_verbose)
          # need to make sure entities are cached before we start the background loop thread
          @device.entities
          @device.stream_states
          @loop_thread = Thread.new do
            @device.loop
          rescue IOError, Errno::ECONNRESET, ConnectionClosedError
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

    def signal_update
      @updates_mutex.synchronize do
        @updates_condition.broadcast
      end
    end

    def waitable_error?(error)
      error.is_a?(StandardError) ||
        error.is_a?(RSpec::Expectations::ExpectationNotMetError)
    end

    def log_line_matches?(current_logs, pattern)
      current_logs.any? do |message|
        pattern.is_a?(Regexp) ? message.match?(pattern) : message.include?(pattern)
      end
    end
  end
end

host_device_groups = []
host_device = nil
has_esphome_exe = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |path| # rubocop:disable RSpec/LeakyLocalVariable
  executable = File.join(path, "esphome")
  File.file?(executable) && File.executable?(executable)
end
tmp_dir = nil

RSpec.configure do |config|
  config.before(:suite) do
    next unless has_esphome_exe

    tmp_dir = File.join(__dir__, "../../tmp")
    FileUtils.mkdir_p(tmp_dir)
    Dir.chdir(tmp_dir) do
      packages_yaml = +"packages:\n"
      host_device_groups.map { |g| g.metadata[:yaml] }.each_with_index do |yaml, index|
        file_name = "#{index}.yaml"
        File.write(file_name, yaml)
        packages_yaml << "  - !include #{file_name}\n"
      end

      host_device = ESPHome::HostDevice.new(packages_yaml, tmp_directory: false).tap(&:start) # rubocop:disable RSpec/LeakyLocalVariable
    end
  end

  config.after(:suite) do
    host_device&.stop
  end
end

RSpec.shared_context "with Host Device" do
  before do
    skip "`esphome` executable is required for host device specs" unless has_esphome_exe
  end

  host_device_groups << self

  def entity_named(name)
    host_device.device.entities.values.find { |entity| entity.name == name }
  end

  let(:host_device) do
    host_device
  end
end
