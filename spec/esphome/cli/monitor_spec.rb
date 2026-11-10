# frozen_string_literal: true

require "esphome/cli/monitor"

RSpec.describe ESPHome::Cli::Monitor do
  let(:device) { instance_double(ESPHome::Device) }
  let(:monitor) { described_class.new(device) }
  let(:window) { instance_double(Curses::Window) }
  let(:disconnect_callbacks) { [] }
  let(:reader_started) { Queue.new }
  let(:reader_stopped) { Queue.new }

  before do
    allow(device).to receive(:device_logger=)
    allow(device).to receive(:connection_logger=)
    allow(device).to receive(:on_message)
    allow(device).to receive(:on_connect)
    allow(device).to receive(:on_disconnect) { |&callback| disconnect_callbacks << callback }
    allow(device).to receive(:connect)
    allow(device).to receive(:loop) do
      reader_started << Thread.current
      begin
        sleep
      ensure
        reader_stopped << true
      end
    end
    allow(device).to receive(:disconnect) do
      expect(reader_stopped.pop(true)).to be true
      disconnect_callbacks.each(&:call)
    end
    allow(monitor).to receive(:install_winch_handler)
    allow(monitor).to receive(:ensure_screen) { monitor.instance_variable_set(:@win, window) }
    allow(monitor).to receive(:process_ui_events)
    allow(monitor).to receive(:close_screen)
  end

  it "stops the reader before disconnecting on Escape without reconnecting" do
    reader = nil
    allow(window).to receive(:getch) do
      reader = reader_started.pop
      27
    end

    monitor.run

    expect(reader).not_to be_alive
    expect(device).to have_received(:connect).once
    expect(device).to have_received(:disconnect).once
    expect(monitor).to have_received(:close_screen).once
  end

  it "stops the reader and disconnects on Interrupt" do
    allow(window).to receive(:getch) do
      reader_started.pop
      raise Interrupt
    end

    monitor.run

    expect(device).to have_received(:connect).once
    expect(device).to have_received(:disconnect).once
    expect(monitor).to have_received(:close_screen).once
  end

  it "cleans up when the UI raises an exception" do
    allow(window).to receive(:getch) do
      reader_started.pop
      raise "UI failed"
    end

    expect { monitor.run }.to raise_error(RuntimeError, "UI failed")

    expect(device).to have_received(:connect).once
    expect(device).to have_received(:disconnect).once
    expect(monitor).to have_received(:close_screen).once
  end
end
