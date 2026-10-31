# frozen_string_literal: true

require "cli/command"

RSpec.describe Icarus::Mod::CLI::Validate, "#repo" do
  subject(:validate_command) { described_class.new([], { verbose: [true], json: }) }

  let(:json) { false }
  let(:check_double) { instance_double(Icarus::Mod::Tools::RepoCheck) }
  let(:result) do
    {
      repo: "owner/repo", exists: true, private: false, archived: false, default_branch: "main",
      info_files: { modinfo: "https://raw.githubusercontent.com/owner/repo/main/modinfo.json", toolinfo: nil },
      problems: [],
      entries: [{ type: "mod", name: "Mod", author: "Me", version: "1.0", errors: [], warnings: ["w1"],
                  links: [{ field: "files.zip", url: "https://x/y.zip", status: 200, final_host: "x" }] }],
      valid: true
    }
  end

  before do
    allow(Icarus::Mod::Tools::RepoCheck).to receive(:new).and_return(check_double)
    allow(check_double).to receive(:call).and_return(result)
  end

  it "passes the repo argument to RepoCheck" do
    expect { validate_command.repo("owner/repo") }.to output.to_stdout.and raise_error(SystemExit)
    expect(Icarus::Mod::Tools::RepoCheck).to have_received(:new).with("owner/repo")
  end

  it "exits 0 when valid" do
    expect { validate_command.repo("owner/repo") }.to output(%r{owner/repo}).to_stdout.and raise_error(SystemExit) { |e|
      expect(e.status).to eq(0)
    }
  end

  it "prints warnings in human output" do
    expect { validate_command.repo("owner/repo") }.to output(/w1/).to_stdout.and raise_error(SystemExit)
  end

  context "when not valid" do
    before { result.merge!(valid: false, problems: ["repository is archived"]) }

    it "exits 1 and prints the problems" do
      expect { validate_command.repo("owner/repo") }.to output(/repository is archived/).to_stdout.and raise_error(SystemExit) { |e|
        expect(e.status).to eq(1)
      }
    end
  end

  context "with --json" do
    let(:json) { true }

    it "prints exactly the result as JSON on stdout" do
      printed = satisfy { |out| JSON.parse(out, symbolize_names: true) == result }
      expect { validate_command.repo("owner/repo") }.to output(printed).to_stdout.and raise_error(SystemExit) { |e|
        expect(e.status).to eq(0)
      }
    end
  end

  context "when RepoCheck raises an Error" do
    before { allow(check_double).to receive(:call).and_raise(Icarus::Mod::Tools::RepoCheck::Error, "GitHub API error: rate limit") }

    it "exits 2 with the message on stderr" do
      expect { validate_command.repo("owner/repo") }.to output(/rate limit/).to_stderr.and raise_error(SystemExit) { |e|
        expect(e.status).to eq(2)
      }
    end
  end
end
