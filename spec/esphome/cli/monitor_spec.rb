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

  it "resizes and redraws the background while a popup is active" do
    console = instance_double(IO, winsize: [30, 100])
    monitor.instance_variable_set(:@win, window)
    monitor.instance_variable_set(:@screen_initialized, true)
    monitor.instance_variable_set(:@sub_active, true)
    allow(monitor).to receive(:process_ui_events).and_call_original
    allow(monitor).to receive(:render_all)
    allow(IO).to receive(:console).and_return(console)
    allow(Curses).to receive_messages(lines: 24, cols: 80)
    allow(Curses).to receive(:resizeterm)
    allow(window).to receive_messages(maxy: 24, maxx: 80)
    allow(window).to receive(:resize)
    allow(window).to receive(:clear)

    monitor.resize_display

    expect(Curses).to have_received(:resizeterm).with(30, 100)
    expect(window).to have_received(:resize).with(30, 100)
    expect(monitor).to have_received(:render_all).once
    expect(monitor).not_to be_resize_pending
  end

  it "does not generate another resize event when handling a resize key at the current size" do
    console = instance_double(IO, winsize: [30, 100])
    monitor.instance_variable_set(:@win, window)
    monitor.instance_variable_set(:@screen_initialized, true)
    monitor.instance_variable_set(:@sub_active, true)
    allow(monitor).to receive(:process_ui_events).and_call_original
    allow(monitor).to receive(:render_all)
    allow(IO).to receive(:console).and_return(console)
    allow(Curses).to receive_messages(lines: 30, cols: 100)
    allow(Curses).to receive(:resizeterm)
    allow(window).to receive_messages(maxy: 30, maxx: 100)
    allow(window).to receive(:resize)
    allow(window).to receive(:clear)

    monitor.resize_display

    expect(Curses).not_to have_received(:resizeterm)
    expect(window).not_to have_received(:resize)
    expect(monitor).to have_received(:render_all).once
  end
end
