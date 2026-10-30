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
      transient_failures: [],
      update: true
    )
    allow(toolinfo_sync_double).to receive_messages(
      repositories: ["owner/repo"],
      data: [double(download_url: "https://example.com/toolinfo.json")],
      transient_failures: [],
      update: true
    )
    allow(mods_sync_double).to receive_messages(
      info_array: [modinfo],
      mods: [],
      find: nil,
      find_info: nil,
      transient_failures: [],
      update: true,
      delete: true
    )
    allow(tools_sync_double).to receive_messages(
      info_array: [toolinfo],
      tools: [],
      find: nil,
      find_info: nil,
      transient_failures: [],
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

    context "when a repository could not be searched this run" do
      before do
        allow(modinfo_sync_double).to receive(:transient_failures).and_return(["https://github.com/flaky/repo"])
      end

      it "still saves the modinfo URLs it found" do
        expect { sync_command.modinfo }.to output.to_stdout.and output.to_stderr
        expect(modinfo_sync_double).to have_received(:update).with(["https://example.com/modinfo.json"])
      end

      it "warns that the repository's existing entries were kept" do
        expect { sync_command.modinfo }.to output(%r{flaky/repo.*kept}m).to_stderr.and output.to_stdout
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
    context "when an existing mod no longer appears in any modinfo file" do
      let(:stale_mod) { Icarus::Mod::Tools::Modinfo.new({ name: "Stale", author: "Someone", description: "Gone" }, id: "stale-id") }

      before do
        allow(mods_sync_double).to receive(:mods).and_return([stale_mod])
      end

      it "deletes it when every modinfo URL was read or is gone (the author removed it)" do
        expect { sync_command.mods }.to output(/Deleted 1 outdated items/).to_stdout
        expect(mods_sync_double).to have_received(:delete).with(stale_mod)
      end

      context "when a modinfo URL failed transiently this run" do
        let(:flaky_url) { "https://raw.githubusercontent.com/someone/mods/main/modinfo.json" }

        before do
          allow(mods_sync_double).to receive(:transient_failures).and_return([flaky_url])
        end

        it "deletes nothing, because its docs cannot be told apart from the rest" do
          expect { sync_command.mods }.to output.to_stdout.and output.to_stderr
          expect(mods_sync_double).not_to have_received(:delete)
        end

        it "warns which URL failed and that the outdated items were kept" do
          expect { sync_command.mods }.to output(/#{Regexp.escape(flaky_url)}.*kept/m).to_stderr.and output.to_stdout
        end

        it "still creates and updates the mods it could read" do
          expect { sync_command.mods }.to output.to_stdout.and output.to_stderr
          expect(mods_sync_double).to have_received(:update).with(modinfo)
        end
      end
    end
  end

  describe "#tools" do
    context "when a toolinfo URL failed transiently this run" do
      let(:stale_tool) { Icarus::Mod::Tools::Toolinfo.new({ name: "Stale", author: "Someone", description: "Gone" }, id: "stale-tool") }

      before do
        allow(tools_sync_double).to receive_messages(tools: [stale_tool], transient_failures: ["https://example.com/toolinfo.json"])
      end

      it "deletes nothing" do
        expect { sync_command.tools }.to output.to_stdout.and output.to_stderr
        expect(tools_sync_double).not_to have_received(:delete)
      end
    end

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

  describe "#cleanup" do
    let(:options) { { verbose: [true], dry_run: false } }
    let(:now) { Time.now }
    let(:mod_klass) { Icarus::Mod::Tools::Modinfo }
    let(:tool_klass) { Icarus::Mod::Tools::Toolinfo }
    # mod1 is the oldest doc (the ID clients already hold); mod2 was created later but updated most recently
    let(:mod1) do
      mod_klass.new({ name: "DupeMod", author: "Author1", description: "Old", version: "1.0" },
                    id: "mod1", created: now - 7200, updated: now - 3600)
    end
    let(:mod2) do
      mod_klass.new({ name: "DupeMod", author: "Author1", description: "New", version: "2.0" },
                    id: "mod2", created: now - 60, updated: now)
    end
    let(:mod3) do
      mod_klass.new({ name: "UniqueMod", author: "Author2", description: "Test" }, id: "mod3", created: now, updated: now)
    end
    let(:tool1) do
      tool_klass.new({ name: "DupeTool", author: "Author1", description: "Old" }, id: "tool1", created: now - 7200, updated: now - 3600)
    end
    let(:tool2) do
      tool_klass.new({ name: "DupeTool", author: "Author1", description: "New" }, id: "tool2", created: now - 60, updated: now)
    end

    before do
      allow(firestore_double).to receive_messages(mods: [mod1, mod2, mod3], tools: [tool1, tool2], delete: true, replace_data: true)
    end

    it "identifies duplicate mods by name and author" do
      expect { sync_command.cleanup }.to output(/Found 1 duplicate mod/).to_stdout
    end

    it "identifies duplicate tools by name and author" do
      expect { sync_command.cleanup }.to output(/Found 1 duplicate tool/).to_stdout
    end

    it "keeps the oldest entry, whose ID clients already hold" do
      expect { sync_command.cleanup }.to output(/Keeping.*mod1/).to_stdout
    end

    it "copies the most recently updated entry's data onto the keeper" do
      expect { sync_command.cleanup }.to output(String).to_stdout
      expect(firestore_double).to have_received(:replace_data).with(:mod, id: "mod1", data: mod2.data)
      expect(firestore_double).to have_received(:replace_data).with(:tool, id: "tool1", data: tool2.data)
    end

    it "copies before deleting" do
      expect { sync_command.cleanup }.to output(String).to_stdout
      expect(firestore_double).to have_received(:replace_data).with(:mod, any_args).ordered
      expect(firestore_double).to have_received(:delete).with(:mod, mod2).ordered
    end

    it "deletes the newer duplicate entries" do
      expect { sync_command.cleanup }.to output(String).to_stdout
      expect(firestore_double).to have_received(:delete).with(:mod, mod2)
      expect(firestore_double).to have_received(:delete).with(:tool, tool2)
      expect(firestore_double).not_to have_received(:delete).with(:mod, mod1)
    end

    it "does not delete unique entries" do
      expect { sync_command.cleanup }.to output(String).to_stdout
      expect(firestore_double).not_to have_received(:delete).with(:mod, mod3)
    end

    context "when the oldest entry is also the most recently updated" do
      let(:mod1) do
        mod_klass.new({ name: "DupeMod", author: "Author1", description: "Old" }, id: "mod1", created: now - 7200, updated: now + 60)
      end

      it "does not copy anything onto the keeper" do
        expect { sync_command.cleanup }.to output(String).to_stdout
        expect(firestore_double).not_to have_received(:replace_data).with(:mod, any_args)
        expect(firestore_double).to have_received(:delete).with(:mod, mod2)
      end
    end

    context "when created_at is missing" do
      let(:mod1) { mod_klass.new({ name: "DupeMod", author: "Author1", description: "Old" }, id: "mod1", updated: now) }
      let(:mod2) { mod_klass.new({ name: "DupeMod", author: "Author1", description: "New" }, id: "mod2", updated: now - 3600) }

      it "falls back to the earliest updated_at" do
        expect { sync_command.cleanup }.to output(/Keeping.*mod2/).to_stdout
      end
    end

    context "when timestamps tie" do
      let(:mod1) { mod_klass.new({ name: "DupeMod", author: "Author1", description: "A" }, id: "zzz", created: now, updated: now) }
      let(:mod2) { mod_klass.new({ name: "DupeMod", author: "Author1", description: "B" }, id: "aaa", created: now, updated: now) }

      it "falls back to the lowest id" do
        expect { sync_command.cleanup }.to output(/Keeping.*aaa/).to_stdout
      end
    end

    context "when copying onto the keeper fails" do
      before do
        allow(firestore_double).to receive(:replace_data).with(:mod, any_args).and_return(false)
      end

      it "deletes nothing from that group and warns" do
        expect { sync_command.cleanup }.to output(/DupeMod/).to_stderr.and output(String).to_stdout
        expect(firestore_double).not_to have_received(:delete).with(:mod, anything)
        expect(firestore_double).to have_received(:delete).with(:tool, tool2)
      end
    end

    context "when no duplicates exist" do
      before do
        allow(firestore_double).to receive_messages(mods: [mod3], tools: [])
      end

      it "reports no duplicates found" do
        expect { sync_command.cleanup }.to output(/No duplicate mods found/).to_stdout
      end
    end

    context "with dry_run enabled" do
      let(:options) { { verbose: [true], dry_run: true } }

      it "changes nothing" do
        expect { sync_command.cleanup }.to output(/Dry run/).to_stdout
        expect(firestore_double).not_to have_received(:delete)
        expect(firestore_double).not_to have_received(:replace_data)
      end

      it "shows what would be kept, copied and deleted" do
        expect { sync_command.cleanup }.to output(/Keeping.*mod1.*Would copy.*mod2.*mod1.*Would delete.*mod2/m).to_stdout
      end
    end
  end
end
