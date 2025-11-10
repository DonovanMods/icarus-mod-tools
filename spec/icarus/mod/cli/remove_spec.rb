require "cli/remove"

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
    context "when the repository exists" do
      before do
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:delete).with(:repositories, repo).and_return(true)
      end

      it "removes the repository from the list" do
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        expect { remove_command.repos(repo) }.to output(/Successfully removed repository/).to_stdout
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

    context "when update fails" do
      before do
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:delete).with(:repositories, repo).and_return(false)
      end

      it "prints an error message and exits" do
        expect do
          remove_command.repos(repo)
        end.to output(/Failed to remove repository/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "when given a full GitHub URL" do
      let(:full_url) { "https://github.com/owner/repo" }

      before do
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:delete).with(:repositories, repo).and_return(true)
      end

      it "strips the URL and removes the repository" do
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        expect { remove_command.repos(full_url) }.to output(/Successfully removed repository/).to_stdout
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
        allow(firestore_double).to receive(:modinfo).and_return([modinfo_entry, "https://example.com/other.json"])
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
end
