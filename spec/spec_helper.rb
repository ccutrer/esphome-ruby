# frozen_string_literal: true

require_relative "support/esphome/host_device"

RSpec.shared_context "with Host Device" do
  before do
    found = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |path|
      executable = File.join(path, "esphome")
      File.file?(executable) && File.executable?(executable)
    end
    skip "`esphome` executable is required for host device specs" unless found
  end

  let(:host_device) do
    ESPHome::HostDevice.new(yaml).tap(&:start)
  end

  after do
    host_device.stop
  end
end
