# frozen_string_literal: true

require "cli/command"
require "tempfile"
require "json"

RSpec.describe Icarus::Mod::CLI::Command do
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
    Icarus::Mod::Config.instance_variable_set(:@config, nil)
  end

  after do
    config_file.close
    config_file.unlink
    Icarus::Mod::Config.instance_variable_set(:@config, nil)
  end

  describe "#initialize" do
    context "with --version flag" do
      it "prints version and exits" do
        expect do
          described_class.new([], { version: true, config: config_file.path })
        end.to output(/IcarusModTool \(imt\) v/).to_stdout.and raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      end
    end

    context "when config file does not exist" do
      it "prints error and exits with status 1" do
        expect do
          described_class.new([], { version: false, config: "/nonexistent/config.json" })
        end.to output(/Could not find or read Config/).to_stderr.and raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end

    context "when config file exists" do
      it "reads the config file" do
        expect(Icarus::Mod::Config).to receive(:read).with(config_file.path)
        described_class.new([], { version: false, config: config_file.path })
      end

      it "creates instance successfully" do
        command = described_class.new([], { version: false, config: config_file.path })
        expect(command).to be_a(described_class)
      end
    end
  end

  describe "subcommands" do
    subject(:command) { described_class.new([], { version: false, config: config_file.path }) }

    it "has sync subcommand" do
      expect(described_class.subcommands).to include("sync")
    end

    it "has list subcommand" do
      expect(described_class.subcommands).to include("list")
    end

    it "has add subcommand" do
      expect(described_class.subcommands).to include("add")
    end

    it "has remove subcommand" do
      expect(described_class.subcommands).to include("remove")
    end

    it "has validate subcommand" do
      expect(described_class.subcommands).to include("validate")
    end
  end
end
