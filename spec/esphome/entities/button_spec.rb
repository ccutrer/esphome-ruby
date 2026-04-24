# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Button do
  include_context "with Host Device"

  let(:yaml) do
    <<~YAML
      button:
        - platform: template
          name: Test Button
    YAML
  end

  it "sends press commands to a template button" do
    expect(host_device.device.entities.size).to be 1
    button = host_device.device.entities.values.find { |e| e.name == "Test Button" }

    expect(button).to be_a described_class

    button.press

    host_device.wait_for_log_line("'Test Button' Pressed.")
  end
end
