require "cli/remove"

RSpec.describe Icarus::Mod::CLI::Remove do
  subject(:remove_command) { described_class.new }

  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:repo) { "owner/repo" }

  before do
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
  end

  describe "#repos" do
    context "when the repository exists" do
      before do
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:update).with(:repositories, [repo, "other/repo"].reject { |r| r == repo }, merge: true).and_return(true)
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
        allow(firestore_double).to receive_messages(repositories: [repo, "other/repo"], update: false)
      end

      it "prints an error message and exits" do
        expect { remove_command.repos(repo) }.to output(/Failed to remove repository/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when given a full GitHub URL" do
      let(:full_url) { "https://github.com/owner/repo" }

      before do
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        allow(firestore_double).to receive(:update).with(:repositories, [repo, "other/repo"].reject { |r| r == repo }, merge: true).and_return(true)
      end

      it "strips the URL and removes the repository" do
        allow(firestore_double).to receive(:repositories).and_return([repo, "other/repo"])
        expect { remove_command.repos(full_url) }.to output(/Successfully removed repository/).to_stdout
      end
    end
  end
end
