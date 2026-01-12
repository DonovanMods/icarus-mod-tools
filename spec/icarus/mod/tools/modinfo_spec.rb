require "tools/modinfo"

RSpec.describe Icarus::Mod::Tools::Modinfo do
  subject(:modinfo) { described_class.new(modinfo_data) }

  let(:modinfo_data) { JSON.parse(File.read("spec/fixtures/modinfo.json"), symbolize_names: true)[:mods].first }
  let(:modinfo_keys) { modinfo_data.keys }
  let(:meta) { {status: {errors: [], warnings: []}} }

  describe "#to_h" do
    it "returns a valid baseinfo Hash" do
      expect(described_class::HASHKEYS | modinfo_keys).to eq(described_class::HASHKEYS)
    end

    it "returns a valid modinfo Hash" do
      expect(modinfo.to_h).to eq(modinfo_data.merge(meta:))
    end
  end

  describe "#file_types" do
    context "when files is set" do
      it "returns all file_types" do
        expect(modinfo.file_types).to eq(%i[pak exmodz zip])
      end
    end
  end

  describe "#valid?" do
    %w[ZIP PAK EXMOD EXMODZ].each do |filetype|
      context "when fileType is '#{filetype}'" do
        before { modinfo_data[:fileType] = filetype }

        it { is_expected.to be_valid }
      end
    end

    context "when file_type is invalid" do
      before { modinfo_data.merge!(files: {foo: "https://example.org/foo"}) }

      it "returns false" do
        expect(modinfo.valid?).to be false
      end

      it "adds to @errors" do
        modinfo.valid?
        expect(modinfo.errors).to include("Invalid fileType: FOO")
      end
    end

    context "when fileType is blank" do
      before { modinfo_data.merge!(files: {}) }

      it "returns false" do
        expect(modinfo.valid?).to be true
      end

      it "adds to @errors" do
        modinfo.valid?
        expect(modinfo.warnings).to eq(["files should not be empty"])
      end
    end

    context "when files URLs are invalid" do
      before { modinfo_data.merge!(files: {pak: "invalid"}) }

      it "returns false" do
        expect(modinfo.valid?).to be false
      end

      it "adds to @errors" do
        modinfo.valid?
        expect(modinfo.errors).to include("Invalid URL: invalid")
      end
    end
  end

  describe "GitHub URL normalization" do
    context "when files contain GitHub blob URLs" do
      let(:modinfo_with_blobs) do
        {
          name: "Test Mod",
          author: "Test",
          description: "Test",
          version: "1.0",
          files: {
            pak: "https://github.com/user/repo/blob/main/mod.pak",
            zip: "https://github.com/user/repo/raw/main/mod.zip"
          },
          imageURL: "https://github.com/user/repo/blob/main/img.png"
        }
      end

      it "normalizes all file URLs" do
        test_modinfo = described_class.new(modinfo_with_blobs)
        expect(test_modinfo.files[:pak]).to eq("https://raw.githubusercontent.com/user/repo/main/mod.pak")
        expect(test_modinfo.files[:zip]).to eq("https://raw.githubusercontent.com/user/repo/main/mod.zip")
      end

      it "normalizes inherited URLs (imageURL, readmeURL)" do
        test_modinfo = described_class.new(modinfo_with_blobs)
        expect(test_modinfo.imageURL).to eq("https://raw.githubusercontent.com/user/repo/main/img.png")
      end

      it "adds warnings for each normalized URL" do
        test_modinfo = described_class.new(modinfo_with_blobs)
        expect(test_modinfo.warnings.length).to eq(3) # pak, zip, imageURL
      end
    end

    context "when files hash is missing" do
      it "does not raise an error" do
        modinfo_without_files = { name: "Test", author: "Test", description: "Test" }
        expect { described_class.new(modinfo_without_files) }.not_to raise_error
      end
    end
  end
end
