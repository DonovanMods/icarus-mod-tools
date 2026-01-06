# frozen_string_literal: true

require "cli/command"

RSpec.describe Icarus::Mod::CLI::List do
  subject(:list_command) { described_class.new([], options) }

  let(:options) { { verbose: [true], sort: "name", filter: [] } }
  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:modinfo_data) { JSON.parse(File.read("spec/fixtures/modinfo.json"), symbolize_names: true)[:mods].first }
  let(:modinfo) { Icarus::Mod::Tools::Modinfo.new(modinfo_data, id: "test-id", updated: Time.now) }
  let(:toolinfo) { Icarus::Mod::Tools::Toolinfo.new(modinfo_data.merge(fileType: "zip", fileURL: "https://example.com/file.zip"), id: "test-id", updated: Time.now) }

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
          output = capture_stdout { list_command.mods }
          alpha_pos = output.index("Alpha Mod")
          test_pos = output.index("Test Icarus Mod")
          expect(alpha_pos).to be < test_pos
        end
      end

      context "sorted by author" do
        let(:options) { { verbose: [true], sort: "author", filter: [] } }

        it "sorts by author" do
          output = capture_stdout { list_command.mods }
          test_pos = output.index("Test User")
          zebra_pos = output.index("Zebra Author")
          expect(test_pos).to be < zebra_pos
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

    context "with invalid sort field" do
      let(:options) { { verbose: [true], sort: "invalid_field", filter: [] } }

      it "raises an error and exits" do
        expect { list_command.mods }.to output(/Invalid sort field/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "with invalid filter field" do
      let(:options) { { verbose: [true], sort: "name", filter: ["invalid_field", "value"] } }

      it "raises an error and exits" do
        expect { list_command.mods }.to output(/Invalid filter field/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "with malformed filter option" do
      let(:options) { { verbose: [true], sort: "name", filter: ["only_one_value"] } }

      it "raises an error and exits" do
        expect { list_command.mods }.to output(/Invalid filter option/).to_stdout.and raise_error(SystemExit)
      end
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
