# frozen_string_literal: true

require "firestore"
require "tools/sync/mods"

RSpec.describe Icarus::Mod::Tools::Sync::Mods do
  subject(:modsync) { described_class.new }

  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:url) { "https://raw.githubusercontent.com/author/mod/master/modinfo.json" }
  let(:modinfo_data) { JSON.parse(File.read("spec/fixtures/modinfo.json"), symbolize_names: true) }
  let(:modinfo) { Icarus::Mod::Tools::Modinfo.new(modinfo_data[:mods].first) }

  before do
    allow(firestore_double).to receive_messages(mods: [], find_by_type: modinfo, update: true, delete: true)
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)

    modsync.instance_variable_set(:@info_array, [modinfo])
  end

  describe "#mods" do
    it "calls Firestore.mods" do
      modsync.mods

      expect(firestore_double).to have_received(:mods)
    end
  end

  describe "#info_array" do
    it "returns an array of Modinfo objects" do
      expect(modsync.info_array).to all(be_a(Icarus::Mod::Tools::Modinfo))
    end
  end

  describe "#find" do
    it "calls Firestore.find_by_type with :mod" do
      modsync.find(modinfo)

      expect(firestore_double).to have_received(:find_by_type).with(type: "mods", name: "Test Icarus Mod", author: "Test User")
    end
  end

  describe "#find_modinfo" do
    it "returns a Modinfo object" do
      expect(modsync.find_info(modinfo)).to be_a(Icarus::Mod::Tools::Modinfo)
    end
  end

  describe "#update" do
    it "calls Firestore.update" do
      modsync.update(modinfo)

      expect(firestore_double).to have_received(:update).with(:mod, modinfo, merge: false)
    end
  end

  describe "#delete" do
    it "calls Firestore.delete" do
      modsync.delete(modinfo)

      expect(firestore_double).to have_received(:delete).with(:mod, modinfo)
    end
  end
end
