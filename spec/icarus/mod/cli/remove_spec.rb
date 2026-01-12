require "cli/remove"
require "tools/sync/helpers"

RSpec.describe Icarus::Mod::CLI::Remove do
  subject(:remove_command) { described_class.new }

  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:repo) { "owner/repo" }

  before do
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
    $firestore = nil  # Reset global state before each test
  end

  after do
    $firestore = nil  # Clean up global state after each test
  end

  describe "#repos" do
    context "when the repository exists (with cascade disabled)" do
      let(:cmd_no_cascade) { described_class.new([], { cascade: false }, {}) }

      before do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:delete).with(:repositories, repo).and_return(true)
      end

      it "removes the repository from the list" do
        expect { cmd_no_cascade.repos(repo) }.to output(/Successfully removed repository/).to_stdout
      end
    end

    context "when the repository does not exist" do
      before do
        allow(firestore_double).to receive(:repositories).and_return(["other/repo"])
      end

      it "prints an error message and exits" do
        expect { remove_command.repos(repo) }.to output(/Repository not found/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "when update fails (with cascade disabled)" do
      let(:cmd_no_cascade) { described_class.new([], { cascade: false }, {}) }

      before do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:delete).with(:repositories, repo).and_return(false)
      end

      it "prints an error message and exits" do
        expect do
          cmd_no_cascade.repos(repo)
        end.to output(/Failed to remove repository/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "when given a full GitHub URL (with cascade disabled)" do
      let(:full_url) { "https://github.com/owner/repo" }
      let(:cmd_no_cascade) { described_class.new([], { cascade: false }, {}) }

      before do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:delete).with(:repositories, repo).and_return(true)
      end

      it "strips the URL and removes the repository" do
        expect { cmd_no_cascade.repos(full_url) }.to output(/Successfully removed repository/).to_stdout
      end
    end
  end

  describe "#modinfo" do
    let(:modinfo_entry) { "https://example.com/modinfo.json" }

    context "when the modinfo entry exists" do
      before do
        allow(firestore_double).to receive(:modinfo).and_return([modinfo_entry, "https://example.com/other.json"])
        allow(firestore_double).to receive(:delete).with(:modinfo, modinfo_entry).and_return(true)
      end

      it "removes the modinfo entry from the list" do
        expect { remove_command.modinfo(modinfo_entry) }.to output(/Successfully removed modinfo entry/).to_stdout
      end
    end

    context "when the modinfo entry does not exist" do
      before do
        allow(firestore_double).to receive(:modinfo).and_return(["https://example.com/other.json"])
      end

      it "prints an error message and exits" do
        expect do
          remove_command.modinfo(modinfo_entry)
        end.to output(/Modinfo entry not found/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "when update fails" do
      before do
        allow(firestore_double).to receive(:modinfo).and_return([modinfo_entry, "https://example.com/other.json"])
        allow(firestore_double).to receive(:delete).with(:modinfo, modinfo_entry).and_return(false)
      end

      it "prints an error message and exits" do
        expect do
          remove_command.modinfo(modinfo_entry)
        end.to output(/Failed to remove modinfo entry/).to_stderr.and raise_error(SystemExit)
      end
    end
  end

  describe "#mod" do
    let(:mod_id) { "test_mod_id" }
    let(:mod_double) do
      double("Modinfo", id: mod_id, name: "Test Mod", author: "Test Author")
    end

    context "when the mod exists" do
      before do
        allow(firestore_double).to receive(:mods).and_return([mod_double])
        allow(firestore_double).to receive(:delete).with(:mod, mod_double).and_return(true)
      end

      it "removes the mod from the collection" do
        expect { remove_command.mod(mod_id) }.to output(/Successfully removed mod/).to_stdout
      end
    end

    context "when the mod does not exist" do
      before do
        allow(firestore_double).to receive(:mods).and_return([])
      end

      it "prints an error message and exits" do
        expect { remove_command.mod(mod_id) }.to output(/Mod not found/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "when delete fails" do
      before do
        allow(firestore_double).to receive(:mods).and_return([mod_double])
        allow(firestore_double).to receive(:delete).with(:mod, mod_double).and_return(false)
      end

      it "prints an error message and exits" do
        expect { remove_command.mod(mod_id) }.to output(/Failed to remove mod/).to_stderr.and raise_error(SystemExit)
      end
    end
  end

  describe "#tool" do
    let(:tool_id) { "test_tool_id" }
    let(:tool_double) do
      double("Toolinfo", id: tool_id, name: "Test Tool", author: "Test Author")
    end

    context "when the tool exists" do
      before do
        allow(firestore_double).to receive(:tools).and_return([tool_double])
        allow(firestore_double).to receive(:delete).with(:tool, tool_double).and_return(true)
      end

      it "removes the tool from the collection" do
        expect { remove_command.tool(tool_id) }.to output(/Successfully removed tool/).to_stdout
      end
    end

    context "when the tool does not exist" do
      before do
        allow(firestore_double).to receive(:tools).and_return([])
      end

      it "prints an error message and exits" do
        expect { remove_command.tool(tool_id) }.to output(/Tool not found/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "when delete fails" do
      before do
        allow(firestore_double).to receive(:tools).and_return([tool_double])
        allow(firestore_double).to receive(:delete).with(:tool, tool_double).and_return(false)
      end

      it "prints an error message and exits" do
        expect { remove_command.tool(tool_id) }.to output(/Failed to remove tool/).to_stderr.and raise_error(SystemExit)
      end
    end
  end

  describe "#repos with cascade delete" do
    let(:modinfo_url) { "https://raw.githubusercontent.com/owner/repo/main/modinfo.json" }
    let(:toolinfo_url) { "https://raw.githubusercontent.com/owner/repo/main/toolinfo.json" }
    let(:other_url) { "https://example.com/other.json" }
    let(:mod_double) do
      double("Modinfo", id: "mod_id", name: "Test Mod", author: "Test Author")
    end
    let(:tool_double) do
      double("Toolinfo", id: "tool_id", name: "Test Tool", author: "Test Author")
    end

    before do
      allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
      allow(firestore_double).to receive(:modinfo).and_return([modinfo_url, other_url])
      allow(firestore_double).to receive(:toolinfo).and_return([toolinfo_url])
      allow(firestore_double).to receive(:mods).and_return([mod_double])
      allow(firestore_double).to receive(:tools).and_return([tool_double])
    end

    context "with cascade enabled" do
      let(:cmd_with_cascade) { described_class.new([], { cascade: true }, {}) }

      before do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:modinfo).and_return([modinfo_url, other_url])
        allow(firestore_double).to receive(:toolinfo).and_return([toolinfo_url])
        allow(firestore_double).to receive(:mods).and_return([mod_double])
        allow(firestore_double).to receive(:tools).and_return([tool_double])

        # Mock the retrieve_from_url calls that happen inside delete_entities_from_url
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(modinfo_url).and_return(
          { mods: [{ name: "Test Mod", author: "Test Author" }] }
        )
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(toolinfo_url).and_return(
          { tools: [{ name: "Test Tool", author: "Test Author" }] }
        )
        allow(firestore_double).to receive(:delete).and_return(true)
      end

      it "removes repository and all associated entries" do
        expect(firestore_double).to receive(:delete).with(:modinfo, modinfo_url).ordered
        expect(firestore_double).to receive(:delete).with(:mod, mod_double).ordered
        expect(firestore_double).to receive(:delete).with(:toolinfo, toolinfo_url).ordered
        expect(firestore_double).to receive(:delete).with(:tool, tool_double).ordered
        expect(firestore_double).to receive(:delete).with(:repositories, repo).ordered

        expect do
          cmd_with_cascade.repos(repo)
        end.to output(/Successfully removed repository and all associated entries/).to_stdout
      end
    end

    context "with cascade disabled" do
      it "only removes the repository" do
        # Create command with options set properly
        cmd = described_class.new([], { cascade: false }, {})
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:delete).with(:repositories, repo).and_return(true)

        expect(firestore_double).to receive(:delete).with(:repositories, repo)
        expect(firestore_double).not_to receive(:delete).with(:modinfo, anything)
        expect(firestore_double).not_to receive(:delete).with(:toolinfo, anything)

        expect { cmd.repos(repo) }.to output(/Successfully removed repository/).to_stdout
      end
    end

    context "when URL fetch fails during cascade" do
      let(:cmd_with_cascade) { described_class.new([], { cascade: true }, {}) }

      before do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        # Make sure there are URLs to fetch
        allow(firestore_double).to receive(:modinfo).and_return([modinfo_url])
        allow(firestore_double).to receive(:toolinfo).and_return([toolinfo_url])

        # Mock the fetch to raise an error
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).and_raise(StandardError.new("Network error"))
        allow(firestore_double).to receive(:delete).and_return(true)
      end

      it "warns about the failure but continues" do
        expect do
          cmd_with_cascade.repos(repo)
        end.to output(/Warning: Could not fetch/).to_stderr
          .and output(/Successfully removed repository and all associated entries/).to_stdout
      end
    end
  end
end
