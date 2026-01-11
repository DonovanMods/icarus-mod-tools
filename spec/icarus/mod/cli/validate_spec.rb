# frozen_string_literal: true

require "cli/command"

RSpec.describe Icarus::Mod::CLI::Validate do
  subject(:validate_command) { described_class.new([], options) }

  let(:options) { { verbose: [true] } }
  let(:validator_double) { instance_double(Icarus::Mod::Tools::Validator) }
  let(:modinfo_data) { JSON.parse(File.read("spec/fixtures/modinfo.json"), symbolize_names: true)[:mods].first }
  let(:toolinfo_data) { JSON.parse(File.read("spec/fixtures/toolinfo.json"), symbolize_names: true)[:tools].first }
  let(:valid_modinfo) { Icarus::Mod::Tools::Modinfo.new(modinfo_data) }
  let(:invalid_modinfo) do
    Icarus::Mod::Tools::Modinfo.new({
      name: "",
      author: "",
      description: "",
      version: "1.0"
    })
  end
  let(:warning_modinfo) do
    Icarus::Mod::Tools::Modinfo.new(
      modinfo_data.merge(version: "not-a-version")
    )
  end

  before do
    allow(Icarus::Mod::Tools::Validator).to receive(:new).and_return(validator_double)
  end

  describe "#modinfo" do
    it "creates a Validator with :modinfo type" do
      allow(validator_double).to receive(:array).and_return([valid_modinfo])

      expect { validate_command.modinfo }.to raise_error(SystemExit)
      expect(Icarus::Mod::Tools::Validator).to have_received(:new).with(:modinfo)
    end

    context "when all entries are valid" do
      before do
        allow(validator_double).to receive(:array).and_return([valid_modinfo])
      end

      it "exits with code 0" do
        expect { validate_command.modinfo }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      end
    end

    context "when entries have errors" do
      before do
        allow(validator_double).to receive(:array).and_return([invalid_modinfo])
      end

      it "exits with code 1" do
        expect { validate_command.modinfo }.to output(/Name cannot be blank/).to_stdout.and raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end

      it "outputs error messages" do
        expect { validate_command.modinfo }.to output(/cannot be blank/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when entries have warnings" do
      before do
        allow(validator_double).to receive(:array).and_return([warning_modinfo])
      end

      it "outputs warning messages" do
        expect { validate_command.modinfo }.to output(/should be a version string/).to_stdout.and raise_error(SystemExit)
      end

      it "exits with code 0 (warnings don't cause failure)" do
        expect { validate_command.modinfo }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      end
    end

    context "with verbose > 1" do
      let(:options) { { verbose: [true, true] } }

      before do
        allow(validator_double).to receive(:array).and_return([valid_modinfo])
      end

      it "outputs validation progress" do
        expect { validate_command.modinfo }.to output(/Running validation steps/).to_stdout.and raise_error(SystemExit)
      end

      it "outputs SUCCESS for valid entries" do
        expect { validate_command.modinfo }.to output(/SUCCESS/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "with verbose > 1 and errors" do
      let(:options) { { verbose: [true, true] } }

      before do
        allow(validator_double).to receive(:array).and_return([invalid_modinfo])
      end

      it "outputs ERROR label" do
        expect { validate_command.modinfo }.to output(/ERROR/).to_stdout.and raise_error(SystemExit)
      end
    end
  end

  describe "#toolinfo" do
    let(:valid_toolinfo) { Icarus::Mod::Tools::Toolinfo.new(toolinfo_data) }

    it "creates a Validator with :toolinfo type" do
      allow(validator_double).to receive(:array).and_return([valid_toolinfo])

      expect { validate_command.toolinfo }.to raise_error(SystemExit)
      expect(Icarus::Mod::Tools::Validator).to have_received(:new).with(:toolinfo)
    end

    context "when all entries are valid" do
      before do
        allow(validator_double).to receive(:array).and_return([valid_toolinfo])
      end

      it "exits with code 0" do
        expect { validate_command.toolinfo }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      end
    end
  end

  describe "#validate (private method)" do
    context "with mixed valid and invalid entries" do
      before do
        allow(validator_double).to receive(:array).and_return([valid_modinfo, invalid_modinfo])
      end

      it "reports errors for invalid entries" do
        expect { validate_command.modinfo }.to output(/cannot be blank/).to_stdout.and raise_error(SystemExit)
      end

      it "exits with code 1 if any entry has errors" do
        expect { validate_command.modinfo }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end
  end
end
