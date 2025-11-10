# frozen_string_literal: true

require "firestore"
require "github"
require "tools/sync/modinfo_list"

RSpec.describe Icarus::Mod::Tools::Sync::ModinfoList do
  subject(:modinfo_sync) { described_class.new }

  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:github_double) { instance_double(Icarus::Mod::Github) }
  let(:url) { "https://github.com/author/mod" }
  let(:modinfo_url) { "https://raw.githubusercontent.com/author/mod/master/modinfo.json" }
  let(:modinfo_data) { JSON.parse(File.read("spec/fixtures/modinfo.json"), symbolize_names: true) }
  let(:modinfo) { Icarus::Mod::Tools::Modinfo.new(modinfo_data[:mods].first) }
  let(:modinfo_array) { [modinfo] }

  before do
    allow(firestore_double).to receive_messages(repositories: [url], update: true)
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)

    allow(github_double).to receive_messages(find: modinfo_url, "repository=": true)
    allow(Icarus::Mod::Github).to receive(:new).and_return(github_double)

    # rubocop:disable RSpec/SubjectStub -- we're stubbing the helper method which is tested elsewhere
    allow(modinfo_sync).to receive(:retrieve_from_url).with(url).and_return(modinfo_data)
    # rubocop:enable RSpec/SubjectStub
  end

  describe "#repositories" do
    it "calls Firestore.repositories" do
      modinfo_sync.repositories

      expect(firestore_double).to have_received(:repositories)
    end
  end

  describe "#update" do
    it "calls Firestore.update" do
      modinfo_sync.update(modinfo_array)

      expect(firestore_double).to have_received(:update).with(:modinfo, modinfo_array)
    end
  end

  describe "#modinfo" do
    it "returns a modinfo JSON array" do
      expect(modinfo_sync.modinfo(url)).to eq(modinfo_data)
    end
  end

  describe "#modinfo_data" do
    context "when the repository is on Github" do
      it "returns an array of modinfo urls" do
        expect(modinfo_sync.data([url])).to eq([modinfo_url])
      end
    end

    context "when the repository is not on Github" do
      let(:url) { "https://gitlab.com/author/mod" }

      it "returns an empty array" do
        expect(modinfo_sync.data([url])).to eq([])
      end
    end
  end
end
