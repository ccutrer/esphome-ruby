# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Text, yaml: <<~YAML do
  text:
    - platform: template
      id: test_text
      name: Test Text
      mode: TEXT
      optimistic: true
      initial_value: initial text
YAML

  include_context "with Host Device"

  it "sends text commands and receives the updated state" do
    text = entity_named("Test Text")
    expect(text).to be_a(described_class)

    host_device.wait_until do
      expect(text.state).to eql "initial text"
    end

    text.command("updated text")
    host_device.wait_until do
      expect(text.state).to eql "updated text"
    end
  end
end
