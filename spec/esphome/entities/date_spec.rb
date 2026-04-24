# frozen_string_literal: true

require "date"

RSpec.describe ESPHome::Entities::Date, yaml: <<~YAML do
  datetime:
    - platform: template
      id: test_date
      name: Test Date
      type: DATE
      optimistic: true
      initial_value: 2038-01-19
YAML

  include_context "with Host Device"

  it "sends date commands and receives the updated state" do
    date = entity_named("Test Date")
    expect(date).to be_a(described_class)

    host_device.wait_until do
      expect(date.state).to eq(Date.new(2038, 1, 19))
    end

    date.command(Date.new(2026, 4, 24))
    host_device.wait_until do
      expect(date.state).to eq(Date.new(2026, 4, 24))
    end
  end
end
