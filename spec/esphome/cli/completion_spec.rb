# frozen_string_literal: true

require "stringio"

require "esphome/cli/completion"

RSpec.describe ESPHome::Cli::Completion do
  describe ".run" do
    let(:dashboard) do
      instance_double(
        ESPHome::Dashboard,
        devices: [
          { "name" => "kitchen" },
          { "name" => "office" },
          { "name" => "outdoor" }
        ]
      )
    end

    it "prints matching device names for esphome-monitor" do
      allow(ESPHome::Dashboard).to receive(:new).with("http://localhost:6052/").and_return(dashboard)
    end

    it "uses a dashboard URI from the command line" do
      allow(ESPHome::Dashboard).to receive(:new).with("http://dashboard.example/").and_return(dashboard)

      expect do
        described_class.run(
          prefix: "k",
          comp_line: "esphome-monitor http://dashboard.example/ k"
        )
      end.to output("kitchen\n").to_stdout
    end

    it "does not complete extra arguments for single-device commands" do
      allow(ESPHome::Dashboard).to receive(:new)

      expect do
        described_class.run(prefix: "x", comp_line: "esphome-monitor kitchen x")
      end.not_to output.to_stdout

      expect(ESPHome::Dashboard).not_to have_received(:new)
    end

    it "completes extra arguments for multi-device commands" do
      allow(ESPHome::Dashboard).to receive(:new).with("http://localhost:6052/").and_return(dashboard)

      expect do
        described_class.run(
          prefix: "o",
          comp_line: "esphome-update-all kitchen o",
          multi: true
        )
      end.to output("office\noutdoor\n").to_stdout
    end
  end
end
