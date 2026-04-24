# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Button, yaml: <<~YAML do
  button:
    - platform: template
      name: Test Button
      on_press:
        - logger.log:
            level: INFO
            format: "'Test Button' Pressed."
YAML

  include_context "with Host Device"

  it "sends press commands to a template button" do
    button = host_device.device.entities.values.find { |e| e.name == "Test Button" }
    expect(button).to be_a described_class

    button.press
    host_device.wait_for_log_line("'Test Button' Pressed.")
  end
end
