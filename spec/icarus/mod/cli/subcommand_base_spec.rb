# frozen_string_literal: true

require "cli/command"

RSpec.describe Icarus::Mod::CLI::SubcommandBase do
  # Create a test subclass to test the base functionality
  let(:test_class) do
    Class.new(described_class) do
      desc "test_command", "A test command"
      def test_command
        "executed"
      end
    end
  end

  describe "#verbose" do
    context "when verbose option is set once" do
      subject(:command) { test_class.new([], { verbose: [true] }) }

      it "returns 1" do
        expect(command.verbose).to eq(1)
      end
    end

    context "when verbose option is set multiple times" do
      subject(:command) { test_class.new([], { verbose: [true, true, true] }) }

      it "returns the count of verbose flags" do
        expect(command.verbose).to eq(3)
      end
    end
  end

  describe "#verbose?" do
    context "when verbose option is set" do
      subject(:command) { test_class.new([], { verbose: [true] }) }

      it "returns true" do
        expect(command.verbose?).to be true
      end
    end
  end

  describe ".banner" do
    it "returns formatted banner with subcommand prefix" do
      stub_const("Icarus::Mod::CLI::TestCommand", test_class)
      command_double = double(usage: "test_command ARG")
      banner = Icarus::Mod::CLI::TestCommand.banner(command_double)
      expect(banner).to include("test_command")
    end
  end

  describe ".subcommand_prefix" do
    it "converts class name to lowercase command format" do
      stub_const("Icarus::Mod::CLI::TestCommand", test_class)
      expect(Icarus::Mod::CLI::TestCommand.subcommand_prefix).to eq("test-command")
    end

    context "with simple name" do
      it "converts PascalCase to kebab-case" do
        stub_const("Icarus::Mod::CLI::MyCommand", Class.new(described_class))
        expect(Icarus::Mod::CLI::MyCommand.subcommand_prefix).to eq("my-command")
      end
    end
  end

  describe ".exit_on_failure?" do
    it "returns true" do
      expect(described_class.exit_on_failure?).to be true
    end
  end
end
