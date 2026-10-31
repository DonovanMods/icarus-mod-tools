# frozen_string_literal: true

require "github"
require "tools/repo_check"

RSpec.describe Icarus::Mod::Tools::RepoCheck do
  subject(:check) { described_class.new("https://github.com/owner/repo", github:, http:, resolver:) }

  let(:client) { instance_double(Octokit::Client) }
  let(:github) { instance_double(Icarus::Mod::Github, client:) }
  let(:repo_data) { { private: false, archived: false, default_branch: "main" } }
  let(:modinfo_url) { "https://raw.githubusercontent.com/owner/repo/main/modinfo.json" }
  let(:toolinfo_url) { "https://raw.githubusercontent.com/owner/repo/main/toolinfo.json" }
  let(:modinfo_file) { { name: "modinfo.json", download_url: modinfo_url } }
  let(:toolinfo_file) { nil }
  let(:release_url) { "https://github.com/owner/repo/releases/download/v1/Mod.exmodz" }
  let(:cdn_url) { "https://release-assets.githubusercontent.com/x/Mod.exmodz" }
  let(:image_url) { "https://raw.githubusercontent.com/owner/repo/main/i.png" }
  let(:mod) do
    {
      name: "Mod", author: "Me", version: "1.0", description: "A mod",
      files: { exmodz: release_url },
      imageURL: image_url
    }
  end
  let(:modinfo_body) { { mods: [mod] } }
  let(:toolinfo_body) { { tools: [] } }
  let(:responses) { { release_url => [302, cdn_url], cdn_url => [200, nil] } }
  # http is called as http.call(uri, verb) and returns [status, location]
  let(:http) do
    lambda do |uri, verb, _ip|
      responses.fetch([verb, uri.to_s]) { responses.fetch(uri.to_s, [200, nil]) }
    end
  end

  # Every host in these specs counts as public; LinkProbe's own specs cover the address checks
  let(:resolver) { ->(_host) { ["93.184.216.34"] } }

  before do
    allow(github).to receive(:repository=)
    allow(github).to receive(:repository).and_return("owner/repo")
    allow(client).to receive(:repository).with("owner/repo").and_return(repo_data)
    allow(github).to receive(:find).with("modinfo.json").and_return(modinfo_file)
    allow(github).to receive(:find).with("toolinfo.json").and_return(toolinfo_file)
    allow(check).to receive(:retrieve_from_url).with(modinfo_url).and_return(modinfo_body)
    allow(check).to receive(:retrieve_from_url).with(toolinfo_url).and_return(toolinfo_body)
  end

  describe "#call" do
    subject(:result) { check.call }

    context "with a healthy mod repo" do
      it "is valid and reports repo facts" do
        expect(result).to include(repo: "owner/repo", exists: true, private: false, archived: false,
                                  default_branch: "main", problems: [], valid: true)
      end

      it "normalises the repository through Github#repository=" do
        result
        expect(github).to have_received(:repository=).with("https://github.com/owner/repo")
      end

      it "reports the info files" do
        expect(result[:info_files]).to eq(modinfo: modinfo_url, toolinfo: nil)
      end

      it "follows redirects and records the final status and host" do
        link = result[:entries].first[:links].find { |l| l[:field] == "files.exmodz" }
        expect(link).to eq(field: "files.exmodz", url: release_url, status: 200, final_host: "release-assets.githubusercontent.com")
      end

      it "describes the entry" do
        expect(result[:entries].first).to include(type: "mod", name: "Mod", author: "Me", version: "1.0", errors: [], warnings: [])
      end
    end

    context "when the repository does not exist" do
      before { allow(client).to receive(:repository).and_raise(Octokit::NotFound) }

      it "is invalid with exists false" do
        expect(result).to include(exists: false, valid: false)
      end
    end

    context "when the repository is private" do
      let(:repo_data) { { private: true, archived: false, default_branch: "main" } }

      it "is invalid and does not fetch files" do
        expect(result).to include(private: true, valid: false, entries: [])
      end
    end

    context "when the repository is archived" do
      let(:repo_data) { { private: false, archived: true, default_branch: "main" } }

      it "is invalid" do
        expect(result).to include(archived: true, valid: false)
      end
    end

    context "when neither info file exists" do
      let(:modinfo_file) { nil }

      it "is invalid with a problem" do
        expect(result).to include(valid: false)
        expect(result[:problems]).to include(a_string_matching(/modinfo\.json or toolinfo\.json/))
      end
    end

    context "when the info file cannot be fetched" do
      before do
        allow(check).to receive(:retrieve_from_url).with(modinfo_url)
                                                   .and_raise(Icarus::Mod::Tools::Sync::RequestGone, "HTTP Request failed (404)")
      end

      it "records a repo-level problem" do
        expect(result[:valid]).to be(false)
        expect(result[:problems]).to include(a_string_matching(/modinfo\.json.*404/))
      end
    end

    context "when the info file is invalid JSON" do
      before { allow(check).to receive(:retrieve_from_url).with(modinfo_url).and_raise(JSON::ParserError, "nope") }

      it "records a repo-level problem" do
        expect(result[:problems]).to include(a_string_matching(/modinfo\.json.*nope/))
      end
    end

    context "when the body has no mods array" do
      let(:modinfo_body) { { stuff: [] } }

      it "records a repo-level problem" do
        expect(result[:problems]).to include(a_string_matching(/'mods' array/))
        expect(result[:valid]).to be(false)
      end
    end

    context "when entries are not objects" do
      let(:modinfo_body) { { mods: ["x"] } }

      it "records a repo-level problem" do
        expect(result[:problems]).to include(a_string_matching(/must be objects/))
      end
    end

    context "when an entry fails validation" do
      let(:mod) { super().merge(description: "") }

      it "collects the entry errors and is invalid" do
        expect(result[:entries].first[:errors]).to include(a_string_matching(/Description cannot be blank/))
        expect(result[:valid]).to be(false)
      end
    end

    context "when a download link returns 404" do
      before { responses[cdn_url] = [404, nil] }

      it "is an entry error" do
        expect(result[:entries].first[:errors]).to include(a_string_matching(/files\.exmodz.*404/))
        expect(result[:valid]).to be(false)
      end
    end

    context "when imageURL returns 404" do
      before { responses[image_url] = [404, nil] }

      it "is only a warning" do
        entry = result[:entries].first
        expect(entry[:warnings]).to include(a_string_matching(/imageURL.*404/))
        expect(entry[:errors]).to be_empty
        expect(result[:valid]).to be(true)
      end
    end

    context "when HEAD is not allowed" do
      before do
        responses[["HEAD", release_url]] = [405, nil]
        responses[["GET", release_url]] = [206, nil]
      end

      it "falls back to a ranged GET" do
        link = result[:entries].first[:links].find { |l| l[:field] == "files.exmodz" }
        expect(link).to include(status: 206, final_host: "github.com")
      end
    end

    context "when the download is hosted off GitHub" do
      let(:release_url) { "https://example.org/Mod.exmodz" }

      before { responses[release_url] = [200, nil] }

      it "warns but stays valid" do
        expect(result[:entries].first[:warnings]).to include("download hosted off GitHub: example.org")
        expect(result[:valid]).to be(true)
      end
    end

    context "when redirects loop" do
      before { responses[cdn_url] = [302, release_url] }

      it "gives up after 5 redirects with an error" do
        expect(result[:entries].first[:errors]).to include(a_string_matching(/files\.exmodz.*redirect/i))
      end
    end

    context "when the request raises a network error" do
      let(:http) { ->(_uri, _verb, _ip) { raise SocketError, "getaddrinfo" } }

      it "is an entry error" do
        expect(result[:entries].first[:errors]).to include(a_string_matching(/files\.exmodz.*getaddrinfo/))
      end
    end

    context "with a toolinfo.json shipping an exe" do
      let(:modinfo_file) { nil }
      let(:toolinfo_file) { { name: "toolinfo.json", download_url: toolinfo_url } }
      let(:tool_url) { "https://github.com/owner/repo/releases/download/v1/Tool.exe" }
      let(:toolinfo_body) do
        { tools: [{ name: "Tool", author: "Me", version: "1.0", description: "d", fileType: "exe", fileURL: tool_url }] }
      end

      it "warns about the Windows executable" do
        entry = result[:entries].first
        expect(entry).to include(type: "tool", name: "Tool")
        expect(entry[:warnings]).to include("tool ships a Windows executable")
        expect(entry[:links].map { |l| l[:field] }).to include("fileURL")
        expect(result[:valid]).to be(true)
      end
    end

    context "when the GitHub API fails" do
      before { allow(client).to receive(:repository).and_raise(Octokit::TooManyRequests) }

      it "raises an Error for the CLI to report" do
        expect { result }.to raise_error(described_class::Error, /GitHub API/)
      end
    end

    context "when the repository name is malformed" do
      subject(:check) { described_class.new("justaname", github:, http:, resolver:) }

      before { allow(github).to receive(:repository).and_return("justaname") }

      it "raises a usage Error" do
        expect { check.call }.to raise_error(described_class::Error, %r{OWNER/REPO})
      end
    end
  end
end
