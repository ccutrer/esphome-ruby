# frozen_string_literal: true

require "pty"

module SerialProxyPTY
  PATH = "/tmp/esphome-ruby-serial-proxy-#{Process.pid}".freeze

  class << self
    attr_reader :master

    def setup
      @master, @slave = PTY.open
      FileUtils.ln_s(@slave.path, PATH)
    end

    def cleanup
      @master&.close
      @slave&.close
      FileUtils.rm_f(PATH)
    end
  end
end

RSpec.configure do |config|
  config.prepend_before(:suite) do
    SerialProxyPTY.setup
  end

  config.append_after(:suite) do
    SerialProxyPTY.cleanup
  end
end

RSpec.describe ESPHome::SerialProxy, yaml: <<~YAML do
  uart:
    id: proxy_uart
    port: #{SerialProxyPTY::PATH}
    baud_rate: 9600

  serial_proxy:
    name: Test Serial Proxy
    port_type: RS232
    uart_id: proxy_uart
YAML

  include_context "with Host Device"

  let(:serial_master) { SerialProxyPTY.master }
  let(:proxy) { host_device.device.serial_proxies.fetch("Test Serial Proxy") }

  describe ".open" do
    it "silences an IO error when its device loop is closed intentionally" do
      proxy = instance_double(described_class, set_modem_params: nil, open: nil, close: nil)
      allow(proxy).to receive(:closed?).and_return(true)
      device = instance_double(
        ESPHome::Device,
        connect: nil,
        disconnect: nil,
        serial_proxies: { 0 => proxy }
      )
      allow(device).to receive(:loop).and_raise(IOError, "stream closed in another thread")
      allow(ESPHome::Device).to receive(:new).and_return(device)

      expect { described_class.open("device", "key") { nil } }.not_to raise_error
    end

    it "raises unexpected connection errors from its device loop" do
      proxy = instance_double(described_class, set_modem_params: nil, open: nil, close: nil)
      device = instance_double(
        ESPHome::Device,
        connect: nil,
        disconnect: nil,
        serial_proxies: { 0 => proxy }
      )
      allow(device).to receive(:loop).and_raise(Errno::ECONNRESET)
      allow(ESPHome::Device).to receive(:new).and_return(device)

      expect { described_class.open("device", "key") { nil } }.to raise_error(Errno::ECONNRESET)
    end
  end

  it "discovers the proxy by name and instance" do
    expect(proxy).to have_attributes(
      name: "Test Serial Proxy",
      instance: 0,
      port_type: :rs232
    )
    expect(host_device.device.serial_proxies.fetch(0)).to be proxy
    expect(proxy).to be_closed
  end

  it "configures and exchanges binary data through the host UART" do
    proxy.set_modem_params(baud: 19_200, data_bits: 8, parity: :none, stop_bits: 1)
    expect(proxy).to have_attributes(baud: 19_200, data_bits: 8, parity: :none, stop_bits: 1)

    Timeout.timeout(2) { proxy.open }
    expect(proxy).not_to be_closed

    outbound = "from ruby\x00\xff".b
    expect(proxy.write(outbound)).to be outbound.bytesize
    expect(Timeout.timeout(2) { serial_master.readpartial(outbound.bytesize) }).to eql outbound

    inbound = "from host\x00\xfe".b
    serial_master.write(inbound)
    expect(Timeout.timeout(2) { proxy.read(inbound.bytesize) }).to eql inbound
    expect(Timeout.timeout(2) do
      proxy.flush
    end).to be(:SERIAL_PROXY_STATUS_OK).or be(:SERIAL_PROXY_STATUS_ASSUMED_SUCCESS)
  ensure
    Timeout.timeout(2) { proxy&.close }
  end
end
