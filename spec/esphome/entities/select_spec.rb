# frozen_string_literal: true

RSpec.describe ESPHome::Entities::Select, yaml: <<~YAML do
  select:
    - platform: template
      id: test_select
      name: Test Select
      options:
        - Option A
        - Option B
        - Option C
      optimistic: true
      initial_option: Option A
YAML

  include_context "with Host Device"

  it "sends select commands and receives the updated state" do
    select = entity_named("Test Select")
    expect(select).to be_a(described_class)

    host_device.wait_until do
      expect(select.state).to eq("Option A")
    end

    select.command("Option B")
    host_device.wait_until do
      expect(select.state).to eq("Option B")
    end
  end
end
