# frozen_string_literal: true

require "firestore"
require "github"
require "tools/sync/toolinfo_list"

RSpec.describe Icarus::Mod::Tools::Sync::ToolinfoList do
  subject(:toolinfo_sync) { described_class.new }

  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:github_double) { instance_double(Icarus::Mod::Github) }
  let(:url) { "https://github.com/author/tools" }
  let(:toolinfo_url) { "https://raw.githubusercontent.com/author/tool/master/toolinfo.json" }
  let(:toolinfo_data) { JSON.parse(File.read("spec/fixtures/toolinfo.json"), symbolize_names: true) }
  let(:toolinfo) { Icarus::Mod::Tools::Toolinfo.new(toolinfo_data[:tools].first) }
  let(:toolinfo_array) { [toolinfo] }

  before do
    allow(firestore_double).to receive_messages(repositories: [url], update: true)
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)

    allow(github_double).to receive_messages(find: toolinfo_url, "repository=": true)
    allow(Icarus::Mod::Github).to receive(:new).and_return(github_double)

    allow(toolinfo_sync).to receive(:retrieve_from_url).with(url).and_return(toolinfo_data)
    # rubocop:enable RSpec/SubjectStub
  end

  describe "#repositories" do
    it "calls Firestore.repositories" do
      toolinfo_sync.repositories

      expect(firestore_double).to have_received(:repositories)
    end
  end

  describe "#update" do
    it "calls Firestore.update" do
      toolinfo_sync.update(toolinfo_array)

      expect(firestore_double).to have_received(:update).with(:toolinfo, toolinfo_array)
    end
  end

  describe "#toolinfo" do
    it "returns a toolinfo JSON array" do
      expect(toolinfo_sync.toolinfo(url)).to eq(toolinfo_data)
    end
  end

  describe "#toolinfo_data" do
    context "when the repository is on Github" do
      it "returns an array of toolinfo urls" do
        expect(toolinfo_sync.data([url])).to eq([toolinfo_url])
      end
    end

    context "when one repository's GitHub lookup fails transiently" do
      let(:flaky_repo) { "https://github.com/flaky/repo" }
      let(:ok_repo) { "https://github.com/ok/repo" }

      before do
        allow(github_double).to receive(:find) do
          raise Octokit::ServerError if @current_repo == flaky_repo

          toolinfo_url
        end
        allow(github_double).to receive(:repository=) { |repo| @current_repo = repo }
      end

      [Octokit::ServerError, Octokit::TooManyRequests, Faraday::ConnectionFailed.new("down")].each do |error|
        it "skips only that repository on #{error.is_a?(Class) ? error : error.class}" do
          allow(github_double).to receive(:find) do
            raise error if @current_repo == flaky_repo

            toolinfo_url
          end

          result = nil
          expect { result = toolinfo_sync.data([flaky_repo, ok_repo]) }
            .to output(/#{Regexp.escape(flaky_repo)}/).to_stderr
          expect(result).to eq([toolinfo_url])
        end
      end

      it "records the repository as a transient failure" do
        expect { toolinfo_sync.data([flaky_repo, ok_repo]) }.to output.to_stderr
        expect(toolinfo_sync.transient_failures).to eq([flaky_repo])
      end
    end

    context "when the repository has no toolinfo.json (or is gone)" do
      before do
        allow(github_double).to receive(:find).and_return(nil)
      end

      it "skips it without recording a transient failure" do
        expect(toolinfo_sync.data([url])).to eq([])
        expect(toolinfo_sync.transient_failures).to eq([])
      end
    end

    context "when the repository is not on Github" do
      let(:url) { "https://gitlab.com/author/tool" }

      it "returns an empty array" do
        expect(toolinfo_sync.data([url])).to eq([])
      end
    end
  end
end
