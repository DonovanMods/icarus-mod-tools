require "github"
require "ostruct"

RSpec.describe Icarus::Mod::Github do
  subject { github }

  let(:github) { described_class.new }
  let(:repository_stub) { "test/icarus-mod-tools" }
  let(:repository) { "https://api.github.com/#{repository_stub}" }

  before do
    allow(Icarus::Mod::Config).to receive(:github).and_return(
      OpenStruct.new(token: "FAKE_TOKEN")
    )
  end

  it { is_expected.to be_a(described_class) }
  it { is_expected.to respond_to(:client) }
  it { is_expected.to respond_to(:repository) }
  it { is_expected.to respond_to(:repository=) }
  it { is_expected.to respond_to(:all_files) }
  it { is_expected.to respond_to(:find) }

  describe "#client" do
    subject { super().client }

    it { is_expected.to be_a(Octokit::Client) }
  end

  describe "#repository" do
    context "when not set in initialize" do
      let(:github) { described_class.new }

      it "is expected to raise an error" do
        expect { github.repository }.to raise_error("You must specify a repository to use")
      end
    end

    context "when set in initialize" do
      let(:github) { described_class.new(repository) }

      it "strips off the URL" do
        expect(github.repository).to eq("test/icarus-mod-tools")
      end
    end
  end

  describe "#repository=" do
    it "strips off the URL" do
      github.repository = repository

      expect(github.repository).to eq("test/icarus-mod-tools")
    end
  end

  describe "#all_files" do
    let(:github) { described_class.new(repository) }
    let(:file) { {name: "test.txt", type: "file"} }
    let(:dir) { {name: "test-dir", type: "dir", path: "test/dir"} }
    let(:resources) { [file, dir] }

    before do
      allow(github.client).to receive(:contents).with(repository_stub, path: dir[:path]).and_return([])
      allow(github.client).to receive(:contents).with(repository_stub, path: nil).and_return(resources)
    end

    it "calls the client" do
      github.all_files

      expect(github.client).to have_received(:contents).with(repository_stub, path: nil)
    end

    it "calls the client recursively with directories" do
      github.all_files(recursive: true)

      expect(github.client).to have_received(:contents).with(repository_stub, path: dir[:path])
    end

    it "returns an array of files" do
      expect(github.all_files).to eq([file])
    end

    it "sets the resources cache" do
      github.all_files

      expect(github.resources).to eq([file])
    end

    it "uses the resource cache if it exists" do
      github.instance_variable_set(:@resources, [file])
      github.all_files

      expect(github.client).not_to have_received(:contents)
    end

    context "when a block is given" do
      it "yields each file" do
        expect { |b| github.all_files(&b) }.to yield_with_args(file)
      end

      it "returns nil" do
        expect(github.all_files { |f| f }).to be_nil
      end
    end
  end

  describe "#find" do
    let(:pattern) { "test" }
    let(:file) { {name: "test.txt", type: "file"} }

    before do
      allow(github).to receive(:all_files).and_call_original
      github.instance_variable_set(:@resources, [file])
    end

    it "calls #all_files" do
      github.find(pattern)

      expect(github).to have_received(:all_files)
    end

    it "returns the first file that matches the pattern" do
      expect(github.find(pattern)).to eq(file)
    end

    it "returns nil if no file matches the pattern" do
      expect(github.find("no-match")).to be_nil
    end
  end
end
