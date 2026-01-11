# frozen_string_literal: true

require "config"
require "json"
require "tempfile"

RSpec.describe Icarus::Mod::Config do
  let(:valid_config) do
    {
      firebase: {
        credentials: { project_id: "test-project" },
        collections: {
          meta: { modinfo: "meta/modinfo", toolinfo: "meta/toolinfo", repositories: "meta/repos" },
          mods: "mods",
          tools: "tools"
        }
      },
      github: { oauth_token: "test-token" }
    }
  end

  let(:config_file) { Tempfile.new(["config", ".json"]) }

  before do
    config_file.write(JSON.generate(valid_config))
    config_file.rewind
    described_class.instance_variable_set(:@config, nil)
    described_class.instance_variable_set(:@config_file, nil)
  end

  after do
    config_file.close
    config_file.unlink
    described_class.instance_variable_set(:@config, nil)
    described_class.instance_variable_set(:@config_file, nil)
  end

  describe ".read" do
    it "reads and parses the config file" do
      result = described_class.read(config_file.path)

      expect(result).to be_an(OpenStruct)
      expect(result.firebase.credentials.project_id).to eq("test-project")
    end

    it "converts nested hashes to OpenStruct" do
      result = described_class.read(config_file.path)

      expect(result.firebase).to be_an(OpenStruct)
      expect(result.github).to be_an(OpenStruct)
    end

    it "stores the config in @config" do
      described_class.read(config_file.path)

      expect(described_class.instance_variable_get(:@config)).not_to be_nil
    end

    context "when file does not exist" do
      it "raises an error" do
        expect { described_class.read("/nonexistent/path.json") }.to raise_error(Errno::ENOENT)
      end
    end

    context "when file contains invalid JSON" do
      let(:invalid_file) { Tempfile.new(["invalid", ".json"]) }

      before do
        invalid_file.write("not valid json")
        invalid_file.rewind
      end

      after do
        invalid_file.close
        invalid_file.unlink
      end

      it "raises a JSON parse error" do
        expect { described_class.read(invalid_file.path) }.to raise_error(JSON::ParserError)
      end
    end
  end

  describe ".config" do
    context "when config has not been read" do
      before do
        allow(described_class).to receive(:config_file).and_return(config_file.path)
      end

      it "reads the config from default location" do
        result = described_class.config

        expect(result).to be_an(OpenStruct)
      end
    end

    context "when config has already been read" do
      before do
        described_class.read(config_file.path)
      end

      it "returns the cached config" do
        expect(described_class).not_to receive(:read)
        described_class.config
      end

      it "returns the same config object" do
        first_call = described_class.config
        second_call = described_class.config

        expect(first_call).to equal(second_call)
      end
    end
  end

  describe ".firebase" do
    before do
      described_class.read(config_file.path)
    end

    it "returns the firebase section of the config" do
      result = described_class.firebase

      expect(result.credentials.project_id).to eq("test-project")
    end

    it "returns an OpenStruct" do
      expect(described_class.firebase).to be_an(OpenStruct)
    end
  end

  describe ".github" do
    before do
      described_class.read(config_file.path)
    end

    it "returns the github section of the config" do
      result = described_class.github

      expect(result.oauth_token).to eq("test-token")
    end

    it "returns an OpenStruct" do
      expect(described_class.github).to be_an(OpenStruct)
    end
  end
end
