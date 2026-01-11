# frozen_string_literal: true

require "cli/command"

RSpec.describe Icarus::Mod::CLI::Sync do
  subject(:sync_command) { described_class.new([], options) }

  let(:options) { { verbose: [true], dry_run: false, check: false } }
  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:modinfo_sync_double) { instance_double(Icarus::Mod::Tools::Sync::ModinfoList) }
  let(:toolinfo_sync_double) { instance_double(Icarus::Mod::Tools::Sync::ToolinfoList) }
  let(:mods_sync_double) { instance_double(Icarus::Mod::Tools::Sync::Mods) }
  let(:tools_sync_double) { instance_double(Icarus::Mod::Tools::Sync::Tools) }
  let(:modinfo_data) { JSON.parse(File.read("spec/fixtures/modinfo.json"), symbolize_names: true)[:mods].first }
  let(:toolinfo_data) { JSON.parse(File.read("spec/fixtures/toolinfo.json"), symbolize_names: true)[:tools].first }
  let(:modinfo) { Icarus::Mod::Tools::Modinfo.new(modinfo_data) }
  let(:toolinfo) { Icarus::Mod::Tools::Toolinfo.new(toolinfo_data) }

  before do
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)

    allow(modinfo_sync_double).to receive_messages(
      repositories: ["owner/repo"],
      data: [double(download_url: "https://example.com/modinfo.json")],
      update: true
    )
    allow(toolinfo_sync_double).to receive_messages(
      repositories: ["owner/repo"],
      data: [double(download_url: "https://example.com/toolinfo.json")],
      update: true
    )
    allow(mods_sync_double).to receive_messages(
      info_array: [modinfo],
      mods: [],
      find: nil,
      find_info: nil,
      update: true,
      delete: true
    )
    allow(tools_sync_double).to receive_messages(
      info_array: [toolinfo],
      tools: [],
      find: nil,
      find_info: nil,
      update: true,
      delete: true
    )

    allow(Icarus::Mod::Tools::Sync::ModinfoList).to receive(:new).and_return(modinfo_sync_double)
    allow(Icarus::Mod::Tools::Sync::ToolinfoList).to receive(:new).and_return(toolinfo_sync_double)
    allow(Icarus::Mod::Tools::Sync::Mods).to receive(:new).and_return(mods_sync_double)
    allow(Icarus::Mod::Tools::Sync::Tools).to receive(:new).and_return(tools_sync_double)
  end

  after do
    $firestore = nil
  end

  describe "#firestore" do
    it "creates a new Firestore instance" do
      sync_command.firestore
      expect(Icarus::Mod::Firestore).to have_received(:new)
    end

    it "caches the Firestore instance in $firestore" do
      sync_command.firestore
      expect($firestore).to eq(firestore_double)
    end

    it "returns the cached instance on subsequent calls" do
      sync_command.firestore
      sync_command.firestore
      expect(Icarus::Mod::Firestore).to have_received(:new).once
    end
  end

  describe "#success_or_failure" do
    it "returns green Success for true" do
      result = sync_command.success_or_failure(true)
      expect(result).to include("Success")
    end

    it "returns red Failure for false" do
      result = sync_command.success_or_failure(false)
      expect(result).to include("Failure")
    end
  end

  describe "#modinfo" do
    it "creates a ModinfoList sync instance" do
      sync_command.modinfo
      expect(Icarus::Mod::Tools::Sync::ModinfoList).to have_received(:new).with(client: firestore_double)
    end

    it "retrieves repositories" do
      sync_command.modinfo
      expect(modinfo_sync_double).to have_received(:repositories)
    end

    context "when repositories are found" do
      it "retrieves modinfo data" do
        sync_command.modinfo
        expect(modinfo_sync_double).to have_received(:data)
      end

      it "updates firestore with the data" do
        sync_command.modinfo
        expect(modinfo_sync_double).to have_received(:update)
      end
    end

    context "when no repositories are found" do
      before do
        allow(modinfo_sync_double).to receive(:repositories).and_return([])
      end

      it "outputs an error message" do
        expect { sync_command.modinfo }.to output(/Unable to find any repositories/).to_stderr
      end
    end

    context "when dry_run is enabled" do
      let(:options) { { verbose: [true], dry_run: true, check: false } }

      it "does not update firestore" do
        expect { sync_command.modinfo }.to output(/Dry run/).to_stdout
        expect(modinfo_sync_double).not_to have_received(:update)
      end
    end
  end

  describe "#toolinfo" do
    it "creates a ToolinfoList sync instance" do
      sync_command.toolinfo
      expect(Icarus::Mod::Tools::Sync::ToolinfoList).to have_received(:new).with(client: firestore_double)
    end

    it "retrieves repositories" do
      sync_command.toolinfo
      expect(toolinfo_sync_double).to have_received(:repositories)
    end

    context "when repositories are found" do
      it "retrieves toolinfo data" do
        sync_command.toolinfo
        expect(toolinfo_sync_double).to have_received(:data)
      end

      it "updates firestore with the data" do
        sync_command.toolinfo
        expect(toolinfo_sync_double).to have_received(:update)
      end
    end

    context "when no repositories are found" do
      before do
        allow(toolinfo_sync_double).to receive(:repositories).and_return([])
      end

      it "outputs an error message" do
        expect { sync_command.toolinfo }.to output(/Unable to find any repositories/).to_stderr
      end
    end
  end

  describe "#mods" do
    it "creates a Mods sync instance" do
      expect { sync_command.mods }.to output(String).to_stdout
      expect(Icarus::Mod::Tools::Sync::Mods).to have_received(:new).with(client: firestore_double)
    end

    it "retrieves info_array" do
      expect { sync_command.mods }.to output(String).to_stdout
      expect(mods_sync_double).to have_received(:info_array)
    end

    context "when check option is enabled" do
      let(:options) { { verbose: [true], dry_run: false, check: true } }

      it "does not update items" do
        sync_command.mods
        expect(mods_sync_double).not_to have_received(:update)
      end
    end

    context "when modinfo is invalid" do
      before do
        allow(modinfo).to receive(:valid?).and_return(false)
        allow(modinfo).to receive(:errors).and_return(["Missing name"])
      end

      it "skips the invalid item" do
        expect { sync_command.mods }.to output(/Skipping List/).to_stderr
        expect(mods_sync_double).not_to have_received(:update)
      end
    end

    context "when existing mod is found" do
      let(:options) { { verbose: [true, true], dry_run: false, check: false } }

      before do
        allow(mods_sync_double).to receive(:find).and_return("existing-doc-id")
        allow(Icarus::Mod::Config).to receive(:firebase).and_return(
          OpenStruct.new(collections: OpenStruct.new(mods: "test-mods"))
        )
      end

      it "updates the existing mod" do
        expect { sync_command.mods }.to output(/Updating/).to_stdout
      end
    end
  end

  describe "#tools" do
    it "creates a Tools sync instance" do
      expect { sync_command.tools }.to output(String).to_stdout
      expect(Icarus::Mod::Tools::Sync::Tools).to have_received(:new).with(client: firestore_double)
    end

    it "retrieves info_array" do
      expect { sync_command.tools }.to output(String).to_stdout
      expect(tools_sync_double).to have_received(:info_array)
    end
  end

  describe "#all" do
    it "invokes all sync commands in order" do
      expect(sync_command).to receive(:invoke).with(:toolinfo).ordered
      expect(sync_command).to receive(:invoke).with(:tools).ordered
      expect(sync_command).to receive(:invoke).with(:modinfo).ordered
      expect(sync_command).to receive(:invoke).with(:mods).ordered

      expect { sync_command.all }.to output(String).to_stdout
    end
  end
end
