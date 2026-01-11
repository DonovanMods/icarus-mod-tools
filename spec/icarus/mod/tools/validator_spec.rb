# frozen_string_literal: true

require "tools/validator"
require "tools/sync/mods"
require "tools/sync/tools"

RSpec.describe Icarus::Mod::Tools::Validator do
  let(:mods_sync_double) { instance_double(Icarus::Mod::Tools::Sync::Mods) }
  let(:tools_sync_double) { instance_double(Icarus::Mod::Tools::Sync::Tools) }
  let(:modinfo_data) { JSON.parse(File.read("spec/fixtures/modinfo.json"), symbolize_names: true)[:mods].first }
  let(:toolinfo_data) { JSON.parse(File.read("spec/fixtures/toolinfo.json"), symbolize_names: true)[:tools].first }
  let(:modinfo) { Icarus::Mod::Tools::Modinfo.new(modinfo_data) }
  let(:toolinfo) { Icarus::Mod::Tools::Toolinfo.new(toolinfo_data) }

  before do
    allow(Icarus::Mod::Tools::Sync::Mods).to receive(:new).and_return(mods_sync_double)
    allow(Icarus::Mod::Tools::Sync::Tools).to receive(:new).and_return(tools_sync_double)
    allow(mods_sync_double).to receive(:info_array).and_return([modinfo])
    allow(tools_sync_double).to receive(:info_array).and_return([toolinfo])
  end

  describe "#initialize" do
    context "with :modinfo type" do
      subject(:validator) { described_class.new(:modinfo) }

      it "creates a Mods sync instance" do
        validator
        expect(Icarus::Mod::Tools::Sync::Mods).to have_received(:new)
      end

      it "retrieves info_array from Mods sync" do
        validator
        expect(mods_sync_double).to have_received(:info_array)
      end

      it "stores the array" do
        expect(validator.array).to eq([modinfo])
      end
    end

    context "with :toolinfo type" do
      subject(:validator) { described_class.new(:toolinfo) }

      it "creates a Tools sync instance" do
        validator
        expect(Icarus::Mod::Tools::Sync::Tools).to have_received(:new)
      end

      it "retrieves info_array from Tools sync" do
        validator
        expect(tools_sync_double).to have_received(:info_array)
      end

      it "stores the array" do
        expect(validator.array).to eq([toolinfo])
      end
    end

    context "with invalid type" do
      it "raises an ArgumentError" do
        expect { described_class.new(:invalid) }.to raise_error(ArgumentError, /Invalid type/)
      end
    end
  end

  describe "#array" do
    context "with modinfo type" do
      subject(:validator) { described_class.new(:modinfo) }

      it "returns an array of Modinfo objects" do
        expect(validator.array).to all(be_a(Icarus::Mod::Tools::Modinfo))
      end
    end

    context "with toolinfo type" do
      subject(:validator) { described_class.new(:toolinfo) }

      it "returns an array of Toolinfo objects" do
        expect(validator.array).to all(be_a(Icarus::Mod::Tools::Toolinfo))
      end
    end

    context "when sync returns empty array" do
      before do
        allow(mods_sync_double).to receive(:info_array).and_return([])
      end

      it "returns empty array" do
        validator = described_class.new(:modinfo)
        expect(validator.array).to eq([])
      end
    end

    context "when sync returns multiple items" do
      let(:modinfo2) { Icarus::Mod::Tools::Modinfo.new(modinfo_data.merge(name: "Second Mod")) }

      before do
        allow(mods_sync_double).to receive(:info_array).and_return([modinfo, modinfo2])
      end

      it "returns all items" do
        validator = described_class.new(:modinfo)
        expect(validator.array.count).to eq(2)
      end
    end
  end
end
