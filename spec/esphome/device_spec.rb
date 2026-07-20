# frozen_string_literal: true

RSpec.describe ESPHome::Device do
  subject(:device) { described_class.new("127.0.0.1", encryption_key) }

  let(:encryption_key) { ["0" * 32].pack("m0") }

  describe "#connected?" do
    it "is false before connecting" do
      expect(device).not_to be_connected
    end
  end

  describe "#disconnect" do
    it "does nothing when already disconnected" do
      expect { device.disconnect }.not_to raise_error
      expect(device).not_to be_connected
    end

    it "clears connection state when the socket is lost before the disconnect request is sent" do
      socket = instance_double(TCPSocket, close: nil)
      device.instance_variable_set(:@socket, socket)
      device.instance_variable_set(:@noise, Object.new)

      expect(device).to be_connected
      expect(device).to receive(:send).with(instance_of(ESPHome::Api::DisconnectRequest)).and_raise(
        ESPHome::NotConnectedError,
        "Not connected"
      )

      expect { device.disconnect }.not_to raise_error
      expect(device).not_to be_connected
      expect(socket).to have_received(:close)
    end
  end
end
