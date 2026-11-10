# frozen_string_literal: true

require "esphome/cli/monitor"

RSpec.describe ESPHome::Cli::Entities::MenuPrompt do
  let(:cli) { instance_double(ESPHome::Cli::Monitor, resize_pending?: false, resize_display: nil) }
  let(:window) { instance_double(Curses::Window, close: nil) }
  let(:prompt) do
    instance = Class.new do
      include ESPHome::Cli::Entities::MenuPrompt
      include ESPHome::Cli::Entities::FormPrompt

      attr_accessor :cli
    end.new
    instance.cli = cli
    instance
  end

  before do
    allow(prompt).to receive(:dialog_fits?).and_return(true)
    allow(prompt).to receive(:position_dialog_window)
  end

  shared_examples "a resizable popup" do
    [nil, Curses::KEY_RESIZE].each do |resize_key|
      it "keeps the popup open when resizing with #{resize_key.inspect}" do
        inputs = [resize_key, "\n".ord]
        allow(window).to receive(:getch) do
          expect(window).not_to have_received(:close)
          allow(cli).to receive(:resize_pending?).and_return(inputs.size == 2)
          inputs.shift
        end

        expect(open_prompt).to eq(expected_value)
        expect(cli).to have_received(:resize_display).once
        expect(prompt).to have_received(:position_dialog_window).with(window)
        expect(window).to have_received(:close).once
      end
    end
  end

  context "with a menu" do
    subject(:open_prompt) { prompt.send(:prompt_menu, "Mode", %w[Off On]) }

    let(:expected_value) { "Off" }

    before do
      allow(prompt).to receive(:build_dialog_window).and_return(window)
      allow(prompt).to receive(:render_select_options)
    end

    it_behaves_like "a resizable popup"

    it "still accepts a selection without a resize" do
      allow(window).to receive(:getch).and_return(Curses::Key::DOWN, "\n".ord)

      expect(open_prompt).to eq("On")
    end

    it "preserves the selection across a resize" do
      allow(window).to receive(:getch).and_return(Curses::Key::DOWN, Curses::KEY_RESIZE, "\n".ord)

      expect(open_prompt).to eq("On")
      expect(prompt).to have_received(:render_select_options).with(window, "Mode", %w[Off On], 1).twice
    end

    it "waits for the popup to fit again after shrinking the terminal" do
      root = instance_double(Curses::Window)
      allow(cli).to receive(:win).and_return(root)
      allow(prompt).to receive(:dialog_fits?).and_return(true, false, false, true, true)
      allow(window).to receive(:getch).and_return(Curses::KEY_RESIZE, "\n".ord)
      allow(root).to receive(:getch).and_return(Curses::KEY_RESIZE)

      expect(open_prompt).to eq("Off")
      expect(cli).to have_received(:resize_display).twice
      expect(root).to have_received(:getch).once
    end
  end

  context "with a form" do
    subject(:open_prompt) do
      prompt.send(:prompt_form, "Value", initial_value: nil, suffix: nil, field_width: 10)
    end

    let(:root) { instance_double(Curses::Window, maxx: 80, maxy: 24) }
    let(:field) { instance_double(Curses::Field, buffer: "edited value", set_fore: nil, set_back: nil) }
    let(:sub) { instance_double(Curses::Window, move: nil, close: nil) }
    let(:expected_value) { "edited value" }
    let(:form) { instance_double(Curses::Form, post: nil, unpost: nil, driver: nil) }

    before do
      allow(cli).to receive(:win).and_return(root)
      allow(prompt).to receive(:build_form_dialog).and_return([field, form, window, sub])
      allow(prompt).to receive(:safe_addstr)
      allow(window).to receive(:box)
      allow(window).to receive(:setpos)
      allow(window).to receive(:refresh)
      allow(window).to receive(:touch)
      allow(window).to receive_messages(begy: 5, begx: 7, maxx: 14, maxy: 3)
    end

    it_behaves_like "a resizable popup"

    it "preserves the form and its input across a resize" do
      allow(window).to receive(:getch).and_return("x", Curses::KEY_RESIZE, "\n".ord)

      expect(open_prompt).to eq("edited value")
      expect(form).to have_received(:driver).with("x").ordered
      expect(form).to have_received(:driver).with(Curses::REQ_VALIDATION).ordered
      expect(prompt).to have_received(:build_form_dialog).once
      expect(form).to have_received(:post).once
      expect(form).to have_received(:unpost).once
      expect(sub).to have_received(:move).with(6, 9)
    end
  end
end
