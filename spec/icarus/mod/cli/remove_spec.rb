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
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).and_raise(SocketError.new("Network error"))
        allow(firestore_double).to receive(:delete).and_return(true)
      end

      it "warns about the failure but continues" do
        expect do
          cmd_with_cascade.repos(repo)
        end.to output(/Warning: Could not fetch/).to_stderr
          .and output(/Successfully removed repository and all associated entries/).to_stdout
      end
    end

    context "URL matching precision (Fix #3)" do
      let(:cmd_with_cascade) { described_class.new([], { cascade: true }, {}) }

      it "does not match repo names as substrings" do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo])
        # modinfo URL contains "owner/repo-fork" which should NOT match "owner/repo"
        allow(firestore_double).to receive(:modinfo).and_return([
          "https://raw.githubusercontent.com/owner/repo-fork/main/modinfo.json"
        ])
        allow(firestore_double).to receive(:toolinfo).and_return([])
        allow(firestore_double).to receive(:delete).and_return(true)

        # Should not attempt to delete the repo-fork URL
        expect(firestore_double).not_to receive(:delete).with(:modinfo, anything)
        expect(firestore_double).to receive(:delete).with(:repositories, repo)

        expect do
          cmd_with_cascade.repos(repo)
        end.to output(/Successfully removed repository/).to_stdout
      end

      it "matches exact repo names in URLs" do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo])
        # This URL should match because it contains exactly "owner/repo"
        matching_url = "https://raw.githubusercontent.com/owner/repo/main/modinfo.json"
        allow(firestore_double).to receive(:modinfo).and_return([matching_url])
        allow(firestore_double).to receive(:toolinfo).and_return([])
        allow(firestore_double).to receive(:mods).and_return([])
        allow(firestore_double).to receive(:tools).and_return([])
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).and_return({ mods: [] })
        allow(firestore_double).to receive(:delete).and_return(true)

        # Should delete the exact match
        expect(firestore_double).to receive(:delete).with(:modinfo, matching_url)
        expect(firestore_double).to receive(:delete).with(:repositories, repo)

        cmd_with_cascade.repos(repo)
      end
    end

    context "multiple entity matches (Fix #5)" do
      let(:cmd_with_cascade) { described_class.new([], { cascade: true, verbose: [true] }, {}) }
      let(:mod1) { double("Modinfo", id: "mod1", name: "Duplicate Mod", author: "Author") }
      let(:mod2) { double("Modinfo", id: "mod2", name: "Duplicate Mod", author: "Author") }

      before do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo])
        allow(firestore_double).to receive(:modinfo).and_return([modinfo_url])
        allow(firestore_double).to receive(:toolinfo).and_return([])
        # Both mods have same name and author
        allow(firestore_double).to receive(:mods).and_return([mod1, mod2])
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).and_return(
          { mods: [{ name: "Duplicate Mod", author: "Author" }] }
        )
        allow(firestore_double).to receive(:delete).and_return(true)
      end

      it "deletes all matching entities" do
        expect(firestore_double).to receive(:delete).with(:mod, mod1)
        expect(firestore_double).to receive(:delete).with(:mod, mod2)

        expect do
          cmd_with_cascade.repos(repo)
        end.to output(/Note: Found 2 entities matching/).to_stderr
      end
    end

    context "error tracking and reporting (Fix #2 & #6)" do
      let(:cmd_with_cascade) { described_class.new([], { cascade: true }, {}) }

      it "tracks and reports fetch failures" do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo])
        allow(firestore_double).to receive(:modinfo).and_return([modinfo_url])
        allow(firestore_double).to receive(:toolinfo).and_return([])
        # Mock the fetch to fail
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(modinfo_url).and_raise(SocketError.new("Connection failed"))
        allow(firestore_double).to receive(:delete).and_return(true)

        expect do
          cmd_with_cascade.repos(repo)
        end.to output(/Warning: Failed to fetch 1 URL\(s\)/).to_stderr
          .and output(/Successfully removed repository/).to_stdout
      end

      it "tracks and reports delete failures" do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo])
        allow(firestore_double).to receive(:modinfo).and_return([modinfo_url])
        allow(firestore_double).to receive(:toolinfo).and_return([])
        allow(firestore_double).to receive(:mods).and_return([])
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).and_return({ mods: [] })
        # Make modinfo delete fail
        allow(firestore_double).to receive(:delete).with(:modinfo, modinfo_url).and_return(false)
        allow(firestore_double).to receive(:delete).with(:repositories, repo).and_return(true)

        expect do
          cmd_with_cascade.repos(repo)
        end.to output(/Warning: 1 delete operation/).to_stderr
      end
    end

    context "enhanced dry-run preview (Fix #1)" do
      let(:cmd_dry_run) { described_class.new([], { cascade: true, dry_run: true }, {}) }
      let(:mod_double) { double("Modinfo", id: "mod123", name: "Test Mod", author: "Test Author") }
      let(:tool_double) { double("Toolinfo", id: "tool456", name: "Test Tool", author: "Test Author") }

      before do
        allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
        allow(firestore_double).to receive(:repositories).and_return([repo])
        allow(firestore_double).to receive(:modinfo).and_return([modinfo_url])
        allow(firestore_double).to receive(:toolinfo).and_return([toolinfo_url])
        allow(firestore_double).to receive(:mods).and_return([mod_double])
        allow(firestore_double).to receive(:tools).and_return([tool_double])
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(modinfo_url).and_return(
          { mods: [{ name: "Test Mod", author: "Test Author" }] }
        )
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(toolinfo_url).and_return(
          { tools: [{ name: "Test Tool", author: "Test Author" }] }
        )
      end

      it "displays detailed preview of all entities that would be deleted" do
        expect do
          cmd_dry_run.repos(repo)
        end.to output(
          a_string_including("Dry run; no changes will be made")
            .and(including("Would remove:"))
            .and(including("Repository: #{repo}"))
            .and(including("Modinfo URLs: 1"))
            .and(including(modinfo_url))
            .and(including("Mods: 1"))
            .and(including("Test Mod by Test Author (ID: mod123)"))
            .and(including("Toolinfo URLs: 1"))
            .and(including(toolinfo_url))
            .and(including("Tools: 1"))
            .and(including("Test Tool by Test Author (ID: tool456)"))
        ).to_stdout
      end

      it "does not perform any actual deletions" do
        expect(firestore_double).not_to receive(:delete)
        cmd_dry_run.repos(repo)
      end
    end
  end
end
