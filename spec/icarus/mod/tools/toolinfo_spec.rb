# frozen_string_literal: true

require "tools/toolinfo"

RSpec.describe Icarus::Mod::Tools::Toolinfo do
  subject(:toolinfo) { described_class.new(toolinfo_data) }

  let(:toolinfo_data) { JSON.parse(File.read("spec/fixtures/toolinfo.json"), symbolize_names: true)[:tools].first }
  let(:toolinfo_keys) { toolinfo_data.keys }

  describe "#to_h" do
    it "returns a valid toolinfo Hash" do
      expect(toolinfo.to_h.keys).to eq(described_class::HASHKEYS)
    end
  end

  describe "#fileType" do
    it "returns a String" do
      expect(toolinfo.fileType).to be_a(String)
    end

    context "when fileType is not set" do
      before { toolinfo_data.delete(:fileType) }

      it "returns a default fileType" do
        expect(toolinfo.fileType).to eq("zip")
      end
    end
  end

  describe "#fileURL" do
    it "exists" do
      expect(toolinfo).to respond_to(:fileURL)
    end

    it "returns a String" do
      expect(toolinfo.fileURL).to be_a(String)
    end

    it "returns correct info" do
      expect(toolinfo.fileURL).to eq(toolinfo_data[:fileURL])
    end
  end

  describe "#validate" do
    it "is public" do
      expect(toolinfo).to respond_to(:validate)
    end

    it "records errors when called explicitly" do
      toolinfo_data.merge!(fileURL: "invalid")
      expect(toolinfo.validate).to be_truthy
      expect(toolinfo.errors).to include("Invalid fileURL: invalid")
    end
  end

  describe "#valid?" do
    %w[ZIP EXE].each do |filetype|
      context "when fileType is '#{filetype}'" do
        before { toolinfo_data[:fileType] = filetype }

        it { is_expected.to be_valid }
      end
    end

    context "when fileType is notzipx" do
      before { toolinfo_data.merge!(fileType: "notzipx") }

      it "warns that it will become an error" do
        expect(toolinfo.warnings).to include("Invalid fileType: NOTZIPX (this will become an error in a future release)")
      end

      it "remains valid" do
        expect(toolinfo).to be_valid
      end
    end

    context "when fileType has a leading dot" do
      before { toolinfo_data.merge!(fileType: ".EXE") }

      it { is_expected.to be_valid }

      it "has no warnings" do
        expect(toolinfo.warnings).to be_empty
      end
    end

    context "when fileType is not a String" do
      before { toolinfo_data.merge!(fileType: 5) }

      it "reports an error instead of raising" do
        expect(toolinfo.errors).to include("Invalid fileType: 5")
      end
    end

    context "when fileURL is not a String" do
      before { toolinfo_data.merge!(fileURL: 5) }

      it "reports an error instead of raising" do
        expect(toolinfo.errors).to include("Invalid fileURL: 5")
      end
    end

    context "when fileURL is javascript:" do
      before { toolinfo_data.merge!(fileURL: "javascript:alert(1)") }

      it "warns that it will become an error" do
        expect(toolinfo.warnings).to include("Invalid fileURL: javascript:alert(1) (this will become an error in a future release)")
      end
    end

    context "when fileType is invalid" do
      before { toolinfo_data.merge!(fileType: :foo) }

      it "returns false" do
        expect(toolinfo.valid?).to be false
      end

      it "adds to @errors" do
        toolinfo.valid?
        expect(toolinfo.errors).to include("Invalid fileType: FOO")
      end
    end

    context "when filesURL is invalid" do
      before { toolinfo_data.merge!(fileURL: "invalid") }

      it "returns false" do
        expect(toolinfo.valid?).to be false
      end

      it "adds to @errors" do
        toolinfo.valid?
        expect(toolinfo.errors).to include("Invalid fileURL: invalid")
      end
    end
  end

  describe "GitHub URL normalization" do
    context "when fileURL contains GitHub blob URL" do
      let(:toolinfo_with_blob) do
        {
          name: "Test Tool",
          author: "Test",
          description: "Test",
          version: "1.0",
          fileType: "zip",
          fileURL: "https://github.com/user/repo/blob/main/tool.zip",
          imageURL: "https://github.com/user/repo/raw/main/img.png"
        }
      end

      it "normalizes fileURL" do
        test_toolinfo = described_class.new(toolinfo_with_blob)
        expect(test_toolinfo.fileURL).to eq("https://raw.githubusercontent.com/user/repo/main/tool.zip")
      end

      it "normalizes inherited URLs" do
        test_toolinfo = described_class.new(toolinfo_with_blob)
        expect(test_toolinfo.imageURL).to eq("https://raw.githubusercontent.com/user/repo/main/img.png")
      end

      it "adds warnings for normalized URLs" do
        test_toolinfo = described_class.new(toolinfo_with_blob)
        expect(test_toolinfo.warnings.length).to eq(2) # fileURL, imageURL
      end
    end
  end
end
