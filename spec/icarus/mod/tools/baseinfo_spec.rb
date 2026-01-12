require "tools/baseinfo"

RSpec.describe Icarus::Mod::Tools::Baseinfo do
  subject(:baseinfo) { described_class.new(baseinfo_data) }

  let(:baseinfo_array) { JSON.parse(File.read("spec/fixtures/baseinfo.json"), symbolize_names: true)[:mods] }
  let(:baseinfo_data) { baseinfo_array.first }

  describe "#read" do
    context "when given a Hash" do
      it "returns a info Hash" do
        expect(baseinfo.read(baseinfo_data)&.keys).to eq(described_class::HASHKEYS)
      end
    end

    context "when given a String" do
      it "returns a Info Hash" do
        expect(baseinfo.read(baseinfo_data.to_json)&.keys).to eq(described_class::HASHKEYS)
      end
    end
  end

  describe "#uniq_name" do
    it "returns a String with author and name" do
      expect(baseinfo.uniq_name).to eq("#{baseinfo.author}/#{baseinfo.name}")
    end
  end

  describe "#author_id" do
    before { baseinfo_data.merge!(author: "Foo Bar") }

    it "returns a parameterized author String" do
      expect(baseinfo.author_id).to eq("foo_bar")
    end
  end

  describe "#to_json" do
    it "returns a JSON String" do
      expect(baseinfo.to_json).to be_a(String)
    end

    it "returns a valid JSON String" do
      expect(baseinfo.to_json).to eql(baseinfo_data.to_json)
    end
  end

  describe "#to_h" do
    it "returns a Hash" do
      expect(baseinfo.to_h).to be_a(Hash)
    end

    it "returns a valid baseinfo Hash" do
      expect(baseinfo.to_h).to eq(baseinfo_data)
    end
  end

  describe "Data accessors" do
    described_class::HASHKEYS.each do |key|
      it { is_expected.to respond_to(key) }
    end
  end

  describe "#errors?" do
    before { baseinfo.instance_variable_set(:@errors, errors) }

    context "when @errors is empty" do
      let(:errors) { [] }

      it "returns false" do
        expect(baseinfo.errors?).to be false
      end
    end

    context "when @errors is not empty" do
      let(:errors) { %w[foo bar] }

      it "returns true" do
        expect(baseinfo.errors?).to be true
      end
    end
  end

  describe "#errors" do
    let(:errors) { ["foo", "bar", nil, "foo", "bat"] }

    before { baseinfo.instance_variable_set(:@errors, errors) }

    it "returns the cleaned up @errors array" do
      expect(baseinfo.errors).to eq(%w[foo bar bat])
    end
  end

  describe "#validate" do
    it "sets @validated true" do
      expect { baseinfo.validate }.to change { baseinfo.instance_variable_get(:@validated) }.from(false).to(true)
    end
  end

  describe "#valid?" do
    it "calls #validate" do
      baseinfo.valid?

      expect(baseinfo.instance_variable_get(:@validated)).to be(true)
    end

    context "when given valid Baseinfo data" do
      it "returns true" do
        expect(baseinfo.valid?).to be true
      end

      it "does not add to @errors" do
        baseinfo.valid?
        expect(baseinfo.errors).to be_empty
      end

      it "does not add to warnings" do
        baseinfo.valid?
        expect(baseinfo.warnings).to be_empty
      end
    end

    context "when version is blank" do
      before { baseinfo_data.merge!(version: "") }

      it "returns true" do
        expect(baseinfo.valid?).to be true
      end

      it "does not add to @errors" do
        baseinfo.valid?
        expect(baseinfo.errors).to be_empty
      end

      it "adds to @warnings" do
        baseinfo.valid?
        expect(baseinfo.warnings).to eq(["Version should be a version string"])
      end
    end

    context "when version is invalid" do
      before { baseinfo_data.merge!(version: "FOO") }

      it "returns false" do
        expect(baseinfo.valid?).to be true
      end

      it "adds to @warnings" do
        baseinfo.valid?
        expect(baseinfo.warnings).to eq(["Version should be a version string"])
      end
    end

    %w[name author description].each do |key|
      context "when #{key} is blank" do
        before { baseinfo_data.merge!(key.to_sym => "") }

        it "returns false" do
          expect(baseinfo.valid?).to be false
        end

        it "adds to @errors" do
          baseinfo.valid?
          expect(baseinfo.errors).to include("#{key.capitalize} cannot be blank")
        end
      end
    end

    %w[imageURL readmeURL].each do |key|
      context "when #{key} URL is invalid" do
        before { baseinfo_data.merge!(key.to_sym => "invalid") }

        it "returns false" do
          expect(baseinfo.valid?).to be false
        end

        it "adds to @errors" do
          baseinfo.valid?
          expect(baseinfo.errors).to include("Invalid URL #{key.capitalize}: invalid")
        end
      end
    end
  end

  describe "#status" do
    before do
      baseinfo.instance_variable_set(:@errors, ["test error"])
      baseinfo.instance_variable_set(:@warnings, ["test warning"])
    end

    it "has a warnings key" do
      expect(baseinfo.status).to have_key(:warnings)
    end

    it "has an errors key" do
      expect(baseinfo.status).to have_key(:errors)
    end

    context "when warnings exist" do
      it "returns warnings" do
        expect(baseinfo.status[:warnings]).to eq(["test warning"])
      end
    end

    context "when errors exit" do
      it "returns warnings" do
        expect(baseinfo.status[:errors]).to eq(["test error"])
      end
    end
  end

  describe "#normalize_github_url" do
    let(:test_baseinfo) { described_class.new({ name: "Test", author: "Test", description: "Test", version: "1.0" }) }

    context "when URL contains /blob/" do
      it "converts to raw.githubusercontent.com" do
        result = test_baseinfo.send(:normalize_github_url, "https://github.com/user/repo/blob/main/file.zip")
        expect(result).to eq("https://raw.githubusercontent.com/user/repo/main/file.zip")
      end

      it "adds a warning" do
        test_baseinfo.send(:normalize_github_url, "https://github.com/user/repo/blob/main/file.zip")
        expect(test_baseinfo.warnings).to include(a_string_matching(/Auto-fixed/))
      end
    end

    context "when URL uses github.com/raw/" do
      it "converts to raw.githubusercontent.com" do
        result = test_baseinfo.send(:normalize_github_url, "https://github.com/user/repo/raw/main/file.zip")
        expect(result).to eq("https://raw.githubusercontent.com/user/repo/main/file.zip")
      end

      it "adds a warning" do
        test_baseinfo.send(:normalize_github_url, "https://github.com/user/repo/raw/main/file.zip")
        expect(test_baseinfo.warnings).to include(a_string_matching(/Auto-fixed/))
      end
    end

    context "when URL already uses raw.githubusercontent.com" do
      it "does not modify the URL" do
        result = test_baseinfo.send(:normalize_github_url, "https://raw.githubusercontent.com/user/repo/main/file.zip")
        expect(result).to eq("https://raw.githubusercontent.com/user/repo/main/file.zip")
      end

      it "does not add a warning" do
        test_baseinfo.send(:normalize_github_url, "https://raw.githubusercontent.com/user/repo/main/file.zip")
        expect(test_baseinfo.warnings).to be_empty
      end
    end

    context "when URL is not a GitHub URL" do
      it "does not modify the URL" do
        result = test_baseinfo.send(:normalize_github_url, "https://example.com/file.zip")
        expect(result).to eq("https://example.com/file.zip")
      end
    end

    context "when URL is nil or empty" do
      it "returns nil for nil" do
        expect(test_baseinfo.send(:normalize_github_url, nil)).to be_nil
      end

      it "returns empty string for empty" do
        expect(test_baseinfo.send(:normalize_github_url, "")).to eq("")
      end
    end

    context "with various GitHub URL formats" do
      [
        ["https://github.com/owner/repo/blob/main/file.zip",
         "https://raw.githubusercontent.com/owner/repo/main/file.zip"],
        ["https://github.com/owner/repo/raw/main/file.zip",
         "https://raw.githubusercontent.com/owner/repo/main/file.zip"],
        ["https://www.github.com/owner/repo/blob/develop/folder/file.pak",
         "https://raw.githubusercontent.com/owner/repo/develop/folder/file.pak"],
        ["http://github.com/owner/repo/raw/v1.0.0/file.exmodz",
         "http://raw.githubusercontent.com/owner/repo/v1.0.0/file.exmodz"],
        ["https://github.com/owner/repo/blob/abc123def/deep/path/to/file.zip",
         "https://raw.githubusercontent.com/owner/repo/abc123def/deep/path/to/file.zip"]
      ].each do |input, expected|
        it "converts #{input}" do
          result = test_baseinfo.send(:normalize_github_url, input)
          expect(result).to eq(expected)
        end
      end
    end
  end

  describe "#read with GitHub URL normalization" do
    context "when data contains GitHub blob URLs" do
      let(:data_with_blob) do
        {
          name: "Test",
          author: "Author",
          description: "Desc",
          version: "1.0",
          imageURL: "https://github.com/user/repo/blob/main/image.png",
          readmeURL: "https://github.com/user/repo/raw/main/README.md"
        }
      end

      it "normalizes URLs during read" do
        test_instance = described_class.new(data_with_blob)
        expect(test_instance.imageURL).to eq("https://raw.githubusercontent.com/user/repo/main/image.png")
        expect(test_instance.readmeURL).to eq("https://raw.githubusercontent.com/user/repo/main/README.md")
      end

      it "adds warnings for normalized URLs" do
        test_instance = described_class.new(data_with_blob)
        expect(test_instance.warnings.length).to eq(2)
      end
    end
  end
end
