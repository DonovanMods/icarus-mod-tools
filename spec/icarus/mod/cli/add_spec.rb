# frozen_string_literal: true

require "cli/command"
require "tempfile"
require "json"

RSpec.describe Icarus::Mod::CLI::Add do
  subject(:add_command) { described_class.new([], options) }

  let(:options) { { verbose: [true] } }
  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }

  before do
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)
    allow(firestore_double).to receive_messages(
      modinfo: [],
      toolinfo: [],
      repositories: [],
      update: true
    )
  end

  describe "#modinfo" do
    let(:modinfo_url) { "https://example.com/modinfo.json" }

    it "retrieves current modinfo list" do
      add_command.modinfo(modinfo_url)
      expect(firestore_double).to have_received(:modinfo)
    end

    it "updates firestore with new entry" do
      add_command.modinfo(modinfo_url)
      expect(firestore_double).to have_received(:update).with(:modinfo, [modinfo_url], merge: true)
    end

    context "when update succeeds" do
      it "outputs Success" do
        expect { add_command.modinfo(modinfo_url) }.to output(/Success/).to_stdout
      end
    end

    context "when update fails" do
      before do
        allow(firestore_double).to receive(:update).and_return(false)
      end

      it "outputs Failure" do
        expect { add_command.modinfo(modinfo_url) }.to output(/Failure/).to_stdout
      end
    end

    context "when modinfo list already has entries" do
      before do
        allow(firestore_double).to receive(:modinfo).and_return(["https://existing.com/modinfo.json"])
      end

      it "appends to existing list" do
        add_command.modinfo(modinfo_url)
        expect(firestore_double).to have_received(:update).with(
          :modinfo,
          ["https://existing.com/modinfo.json", modinfo_url],
          merge: true
        )
      end
    end
  end

  describe "#toolinfo" do
    let(:toolinfo_url) { "https://example.com/toolinfo.json" }

    it "retrieves current toolinfo list" do
      add_command.toolinfo(toolinfo_url)
      expect(firestore_double).to have_received(:toolinfo)
    end

    it "updates firestore with new entry" do
      add_command.toolinfo(toolinfo_url)
      expect(firestore_double).to have_received(:update).with(:toolinfo, [toolinfo_url], merge: true)
    end

    context "when update succeeds" do
      it "outputs Success" do
        expect { add_command.toolinfo(toolinfo_url) }.to output(/Success/).to_stdout
      end
    end

    context "when update fails" do
      before do
        allow(firestore_double).to receive(:update).and_return(false)
      end

      it "outputs Failure" do
        expect { add_command.toolinfo(toolinfo_url) }.to output(/Failure/).to_stdout
      end
    end
  end

  describe "#repos" do
    let(:repo) { "owner/repo" }

    it "retrieves current repositories list" do
      add_command.repos(repo)
      expect(firestore_double).to have_received(:repositories)
    end

    it "updates firestore with new entry" do
      add_command.repos(repo)
      expect(firestore_double).to have_received(:update).with(:repositories, [repo], merge: true)
    end

    context "when update succeeds" do
      it "outputs Success" do
        expect { add_command.repos(repo) }.to output(/Success/).to_stdout
      end
    end

    context "when update fails" do
      before do
        allow(firestore_double).to receive(:update).and_return(false)
      end

      it "outputs Failure" do
        expect { add_command.repos(repo) }.to output(/Failure/).to_stdout
      end
    end

    context "when repositories list already has entries" do
      before do
        allow(firestore_double).to receive(:repositories).and_return(["existing/repo"])
      end

      it "appends to existing list" do
        add_command.repos(repo)
        expect(firestore_double).to have_received(:update).with(
          :repositories,
          ["existing/repo", repo],
          merge: true
        )
      end
    end
  end

  describe "#mod" do
    let(:modinfo_file) { Tempfile.new(["modinfo", ".json"]) }
    let(:valid_modinfo) do
      {
        mods: [
          {
            name: "Test Mod",
            author: "Test Author",
            version: "1.0",
            description: "A test mod",
            files: { pak: "https://example.com/test.pak" },
            imageURL: "https://example.com/image.png",
            readmeURL: "https://example.com/readme.md"
          }
        ]
      }
    end

    before do
      modinfo_file.write(JSON.generate(valid_modinfo))
      modinfo_file.rewind
    end

    after do
      modinfo_file.close
      modinfo_file.unlink
    end

    context "with valid modinfo file" do
      let(:options) { { verbose: [true], modinfo: modinfo_file.path } }

      it "reads the modinfo file" do
        add_command.mod
        expect(firestore_double).to have_received(:update).with(:mod, instance_of(Icarus::Mod::Tools::Modinfo), merge: true)
      end

      context "when update succeeds" do
        it "outputs Success" do
          expect { add_command.mod }.to output(/Success/).to_stdout
        end
      end

      context "when update fails" do
        before do
          allow(firestore_double).to receive(:update).and_return(false)
        end

        it "outputs Failure" do
          expect { add_command.mod }.to output(/Failure/).to_stdout
        end
      end
    end

    context "with invalid modinfo file path" do
      let(:options) { { verbose: [true], modinfo: "/nonexistent/modinfo.json" } }

      it "outputs error and exits" do
        expect { add_command.mod }.to output(/Invalid data file/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "with nil modinfo path" do
      let(:options) { { verbose: [true], modinfo: nil } }

      it "outputs error and exits" do
        expect { add_command.mod }.to output(/Invalid data file/).to_stderr.and raise_error(SystemExit)
      end
    end

    context "with invalid modinfo content" do
      let(:options) { { verbose: [true], modinfo: modinfo_file.path } }
      let(:invalid_modinfo) do
        {
          mods: [
            {
              name: "", # Invalid: empty name
              author: "",
              version: "1.0",
              description: ""
            }
          ]
        }
      end

      before do
        modinfo_file.rewind
        modinfo_file.truncate(0)
        modinfo_file.write(JSON.generate(invalid_modinfo))
        modinfo_file.rewind
      end

      it "outputs validation error and exits" do
        expect { add_command.mod }.to output(/Invalid modinfo/).to_stderr.and raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end

    context "with multiple mods in file" do
      let(:options) { { verbose: [true], modinfo: modinfo_file.path } }
      let(:multi_modinfo) do
        {
          mods: [
            {
              name: "Test Mod 1",
              author: "Test Author",
              version: "1.0",
              description: "First test mod",
              files: { pak: "https://example.com/test1.pak" },
              imageURL: "https://example.com/image1.png",
              readmeURL: "https://example.com/readme1.md"
            },
            {
              name: "Test Mod 2",
              author: "Test Author",
              version: "2.0",
              description: "Second test mod",
              files: { pak: "https://example.com/test2.pak" },
              imageURL: "https://example.com/image2.png",
              readmeURL: "https://example.com/readme2.md"
            }
          ]
        }
      end

      before do
        modinfo_file.rewind
        modinfo_file.truncate(0)
        modinfo_file.write(JSON.generate(multi_modinfo))
        modinfo_file.rewind
      end

      it "processes each mod" do
        add_command.mod
        expect(firestore_double).to have_received(:update).twice
      end
    end
  end
end
