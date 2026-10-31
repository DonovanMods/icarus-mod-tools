# frozen_string_literal: true

require "cli/command"

RSpec.describe Icarus::Mod::CLI::List do
  subject(:list_command) { described_class.new([], options) }

  let(:options) { { verbose: [true], sort: "name", filter: [] } }
  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:modinfo_data) { JSON.parse(File.read("spec/fixtures/modinfo.json"), symbolize_names: true)[:mods].first }
  let(:toolinfo_data) { JSON.parse(File.read("spec/fixtures/toolinfo.json"), symbolize_names: true)[:tools].first }
  let(:modinfo) { Icarus::Mod::Tools::Modinfo.new(modinfo_data, id: "test-id", updated: Time.now) }
  let(:toolinfo) { Icarus::Mod::Tools::Toolinfo.new(toolinfo_data, id: "test-id", updated: Time.now) }

  before do
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
    allow(firestore_double).to receive_messages(
      modinfo: ["https://example.com/modinfo.json"],
      toolinfo: ["https://example.com/toolinfo.json"],
      repositories: ["owner/repo"],
      mods: [modinfo],
      tools: [toolinfo]
    )
  end

  describe "#modinfo" do
    it "retrieves modinfo list from Firestore" do
      expect { list_command.modinfo }.to output(/https:\/\/example.com\/modinfo.json/).to_stdout
    end

    context "with verbose > 1" do
      let(:options) { { verbose: [true, true], sort: "name", filter: [] } }

      it "shows total count" do
        expect { list_command.modinfo }.to output(/Total: 1/).to_stdout
      end
    end
  end

  describe "#toolinfo" do
    it "retrieves toolinfo list from Firestore" do
      expect { list_command.toolinfo }.to output(/https:\/\/example.com\/toolinfo.json/).to_stdout
    end

    context "with verbose > 1" do
      let(:options) { { verbose: [true, true], sort: "name", filter: [] } }

      it "shows total count" do
        expect { list_command.toolinfo }.to output(/Total: 1/).to_stdout
      end
    end
  end

  describe "#repos" do
    it "retrieves repositories list from Firestore" do
      expect { list_command.repos }.to output(/owner\/repo/).to_stdout
    end

    context "with verbose > 1" do
      let(:options) { { verbose: [true, true], sort: "name", filter: [] } }

      it "shows total count" do
        expect { list_command.repos }.to output(/Total: 1/).to_stdout
      end
    end
  end

  describe "#mods" do
    it "retrieves mods from Firestore" do
      expect { list_command.mods }.to output(/Test Icarus Mod/).to_stdout
    end

    it "displays mod author" do
      expect { list_command.mods }.to output(/Test User/).to_stdout
    end

    it "displays version" do
      expect { list_command.mods }.to output(/v1.0/).to_stdout
    end

    context "with verbose output" do
      it "shows header row" do
        expect { list_command.mods }.to output(/NAME/).to_stdout
      end

      it "shows total count" do
        expect { list_command.mods }.to output(/Total: 1/).to_stdout
      end
    end

    context "with verbose > 1" do
      let(:options) { { verbose: [true, true], sort: "name", filter: [] } }

      it "shows ID column" do
        expect { list_command.mods }.to output(/ID/).to_stdout
      end

      it "shows description column" do
        expect { list_command.mods }.to output(/DESCRIPTION/).to_stdout
      end
    end

    context "with no mods found" do
      before do
        allow(firestore_double).to receive(:mods).and_return([])
      end

      it "outputs no entries message" do
        expect { list_command.mods }.to output(/no entries found/).to_stdout
      end
    end
  end

  describe "#tools" do
    it "retrieves tools from Firestore" do
      expect { list_command.tools }.to output(/Test Icarus Mod/).to_stdout
    end

    context "with no tools found" do
      before do
        allow(firestore_double).to receive(:tools).and_return([])
      end

      it "outputs no entries message" do
        expect { list_command.tools }.to output(/no entries found/).to_stdout
      end
    end
  end

  describe "#list_for_type" do
    context "with sorting" do
      let(:modinfo2) { Icarus::Mod::Tools::Modinfo.new(modinfo_data.merge(name: "Alpha Mod", author: "Zebra Author"), id: "test-id-2", updated: Time.now) }

      before do
        allow(firestore_double).to receive(:mods).and_return([modinfo, modinfo2])
      end

      context "sorted by name (default)" do
        it "sorts alphabetically by name" do
          expect { list_command.mods }.to output(/Alpha Mod.*Test Icarus Mod/m).to_stdout
        end
      end

      context "sorted by author" do
        let(:options) { { verbose: [true], sort: "author", filter: [] } }

        it "sorts by author" do
          expect { list_command.mods }.to output(/Test User.*Zebra Author/m).to_stdout
        end
      end
    end

    context "with filtering" do
      let(:options) { { verbose: [true], sort: "name", filter: ["name", "Test"] } }

      it "filters by the specified field" do
        expect { list_command.mods }.to output(/Test Icarus Mod/).to_stdout
      end

      context "with non-matching filter" do
        let(:options) { { verbose: [true], sort: "name", filter: ["name", "NonExistent"] } }

        it "shows no entries" do
          expect { list_command.mods }.to output(/no entries found/).to_stdout
        end
      end
    end

    context "with a filter value containing regex metacharacters" do
      let(:options) { { verbose: [true], sort: "name", filter: ["name", "(Test"] } }

      it "treats the value literally instead of raising" do
        expect { list_command.mods }.to output(/no entries found/).to_stdout
      end
    end

    context "with a filter on a field that is nil for some entries" do
      let(:options) { { verbose: [true], sort: "name", filter: ["compatibility", "1"] } }

      before do
        allow(firestore_double).to receive(:mods).and_return([Icarus::Mod::Tools::Modinfo.new(modinfo_data.merge(compatibility: nil), id: "nil-id", updated: Time.now)])
      end

      it "does not raise" do
        expect { list_command.mods }.to output(/no entries found/).to_stdout
      end
    end

    context "with a filter on a non-String field" do
      let(:options) { { verbose: [true], sort: "name", filter: ["files", "pak"] } }

      it "matches against the string form of the field" do
        expect { list_command.mods }.not_to raise_error
      end
    end

    context "with a case-insensitive filter" do
      let(:options) { { verbose: [true], sort: "name", filter: ["name", "TEST icarus"] } }

      it "matches regardless of case" do
        expect { list_command.mods }.to output(/Test Icarus Mod/).to_stdout
      end
    end

    context "when sorting by a field that is nil in some entries" do
      let(:options) { { verbose: [true], sort: "compatibility", filter: [] } }
      let(:modinfo2) { Icarus::Mod::Tools::Modinfo.new(modinfo_data.merge(name: "Alpha Mod", compatibility: "1.2"), id: "id-2", updated: Time.now) }
      let(:modinfo3) { Icarus::Mod::Tools::Modinfo.new(modinfo_data.merge(name: "Beta Mod", compatibility: nil), id: "id-3", updated: Time.now) }

      before do
        allow(firestore_double).to receive(:mods).and_return([modinfo2, modinfo3])
      end

      it "does not raise" do
        expect { list_command.mods }.to output(/Alpha Mod/).to_stdout
      end
    end

    context "when sorting by a Hash field" do
      let(:options) { { verbose: [true], sort: "files", filter: [] } }
      let(:modinfo2) { Icarus::Mod::Tools::Modinfo.new(modinfo_data.merge(name: "Alpha Mod", files: {pak: "https://example.com/other.pak"}), id: "id-2", updated: Time.now) }

      before do
        allow(firestore_double).to receive(:mods).and_return([modinfo, modinfo2])
      end

      it "does not raise" do
        expect { list_command.mods }.to output(/Alpha Mod/).to_stdout
      end
    end

    context "when an entry has no updated_at" do
      let(:modinfo) { Icarus::Mod::Tools::Modinfo.new(modinfo_data, id: "test-id") }

      it "does not raise" do
        expect { list_command.mods }.to output(/Test Icarus Mod/).to_stdout
      end
    end

    context "with invalid sort field" do
      let(:options) { { verbose: [true], sort: "invalid_field", filter: [] } }

      it "raises an error and exits" do
        expect { list_command.mods }.to output(/Invalid sort field/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "with invalid filter field" do
      let(:options) { { verbose: [true], sort: "name", filter: ["invalid_field", "value"] } }

      it "raises an error and exits" do
        expect { list_command.mods }.to output(/Invalid filter field/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "with malformed filter option" do
      let(:options) { { verbose: [true], sort: "name", filter: ["only_one_value"] } }

      it "raises an error and exits" do
        expect { list_command.mods }.to output(/Invalid filter option/).to_stderr.and raise_error(SystemExit)
      end
    end
  end
end
