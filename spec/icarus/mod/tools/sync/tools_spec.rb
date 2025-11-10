# frozen_string_literal: true

require "firestore"
require "tools/sync/tools"

RSpec.describe Icarus::Mod::Tools::Sync::Tools do
  subject(:toolsync) { described_class.new }

  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:url) { "https://raw.githubusercontent.com/author/mod/master/toolinfo.json" }
  let(:toolinfo_data) { JSON.parse(File.read("spec/fixtures/toolinfo.json"), symbolize_names: true) }
  let(:toolinfo) { Icarus::Mod::Tools::Toolinfo.new(toolinfo_data[:tools].first) }

  before do
    allow(firestore_double).to receive_messages(tools: [], find_by_type: toolinfo, update: true, delete: true)
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)

    toolsync.instance_variable_set(:@info_array, [toolinfo])
  end

  describe "#tools" do
    it "calls Firestore.tools" do
      toolsync.tools

      expect(firestore_double).to have_received(:tools)
    end
  end

  describe "#info_array" do
    it "returns an array of Toolinfo objects" do
      expect(toolsync.info_array).to all(be_a(Icarus::Mod::Tools::Toolinfo))
    end
  end

  describe "#find" do
    it "calls Firestore.find_by_type with :tool" do
      toolsync.find(toolinfo)

      expect(firestore_double).to have_received(:find_by_type).with(type: "tools", name: "Test Icarus Modding Tool", author: "Test User")
    end
  end

  describe "#find_info" do
    it "returns a Toolinfo object" do
      expect(toolsync.find_info(toolinfo)).to be_a(Icarus::Mod::Tools::Toolinfo)
    end
  end

  describe "#update" do
    it "calls Firestore.update" do
      toolsync.update(toolinfo)

      expect(firestore_double).to have_received(:update).with(:tool, toolinfo, merge: false)
    end
  end

  describe "#delete" do
    it "calls Firestore.delete" do
      toolsync.delete(toolinfo)

      expect(firestore_double).to have_received(:delete).with(:tool, toolinfo)
    end
  end
end
