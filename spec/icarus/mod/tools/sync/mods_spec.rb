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

    context "when JSON parsing fails" do
      let(:valid_url) { "https://example.com/valid.json" }
      let(:invalid_url) { "https://example.com/invalid.json" }
      let(:valid_response) { { mods: [{ name: "Valid Mod", author: "Author", description: "Test" }] } }

      before do
        modsync.instance_variable_set(:@info_array, nil)
        allow(firestore_double).to receive(:modinfo).and_return([valid_url, invalid_url])
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(valid_url).and_return(valid_response)
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(invalid_url).and_raise(
          JSON::ParserError.new("invalid escape character in string: '\\Users\\foo\\bar' at line 1 column 10")
        )
      end

      it "warns with a concise error message without stack trace" do
        stderr_output = StringIO.new
        original_stderr = $stderr
        $stderr = stderr_output

        modsync.info_array

        $stderr = original_stderr
        output = stderr_output.string

        expect(output).to match(/Skipped; Invalid JSON in #{Regexp.escape(invalid_url)}: invalid escape character/)
        expect(output).not_to match(/JSON::Ext::Parser/)
        expect(output).not_to match(/lib\/ruby\/gems/)
      end

      it "skips the invalid URL and continues processing" do
        result = modsync.info_array
        expect(result.length).to eq(1)
        expect(result.first.name).to eq("Valid Mod")
      end
    end

    context "when duplicate mods exist across modinfo URLs" do
      let(:url1) { "https://example.com/repo1/modinfo.json" }
      let(:url2) { "https://example.com/repo2/modinfo.json" }
      let(:mod_data) { { mods: [{ name: "Dupe Mod", author: "Same Author", description: "Test", version: "1.0" }] } }

      before do
        modsync.instance_variable_set(:@info_array, nil)
        allow(firestore_double).to receive(:modinfo).and_return([url1, url2])
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(url1).and_return(mod_data)
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(url2).and_return(mod_data)
      end

      it "deduplicates by name and author" do
        result = modsync.info_array
        expect(result.length).to eq(1)
        expect(result.first.name).to eq("Dupe Mod")
      end
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
