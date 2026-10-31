# frozen_string_literal: true

require "firestore"
require "tools/sync/tools"

RSpec.describe Icarus::Mod::Tools::Sync::Tools do
  subject(:toolsync) { described_class.new }

  let(:firestore_double) { instance_double(Icarus::Mod::Firestore) }
  let(:url) { "https://raw.githubusercontent.com/author/mod/master/toolinfo.json" }
  let(:toolinfo_data) { JSON.parse(File.read("spec/fixtures/toolinfo.json"), symbolize_names: true) }
  let(:toolinfo) { Icarus::Mod::Tools::Toolinfo.new(toolinfo_data[:tools].first) }

  before do
    allow(firestore_double).to receive_messages(tools: [], find_by_type: toolinfo, update: true, delete: true)
    allow(Icarus::Mod::Firestore).to receive(:new).and_return(firestore_double)

    toolsync.instance_variable_set(:@info_array, [toolinfo])
  end

  describe "#tools" do
    it "calls Firestore.tools" do
      toolsync.tools

      expect(firestore_double).to have_received(:tools)
    end
  end

  describe "#info_array" do
    it "returns an array of Toolinfo objects" do
      expect(toolsync.info_array).to all(be_a(Icarus::Mod::Tools::Toolinfo))
    end

    context "when JSON parsing fails" do
      let(:valid_url) { "https://example.com/valid.json" }
      let(:invalid_url) { "https://example.com/invalid.json" }
      let(:valid_response) { { tools: [{ name: "Valid Tool", author: "Author", description: "Test", fileType: "EXE", fileURL: "http://example.com/tool.exe" }] } }

      before do
        toolsync.instance_variable_set(:@info_array, nil)
        allow(firestore_double).to receive(:toolinfo).and_return([valid_url, invalid_url])
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(valid_url).and_return(valid_response)
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(invalid_url).and_raise(
          JSON::ParserError.new("invalid escape character in string: '\\Users\\foo\\bar' at line 1 column 10")
        )
      end

      it "warns with a concise error message without stack trace" do
        stderr_output = StringIO.new
        original_stderr = $stderr
        $stderr = stderr_output

        toolsync.info_array

        $stderr = original_stderr
        output = stderr_output.string

        expect(output).to match(/Skipped; Invalid JSON in #{Regexp.escape(invalid_url)}: invalid escape character/)
        expect(output).not_to match(/JSON::Ext::Parser/)
        expect(output).not_to match(/lib\/ruby\/gems/)
      end

      it "skips the invalid URL and continues processing" do
        result = toolsync.info_array
        expect(result.length).to eq(1)
        expect(result.first.name).to eq("Valid Tool")
      end
    end

    context "when duplicate tools exist across toolinfo URLs" do
      let(:url1) { "https://example.com/repo1/toolinfo.json" }
      let(:url2) { "https://example.com/repo2/toolinfo.json" }
      let(:tool_data) { { tools: [{ name: "Dupe Tool", author: "Same Author", description: "Test", fileType: "EXE", fileURL: "http://example.com/tool.exe" }] } }

      before do
        toolsync.instance_variable_set(:@info_array, nil)
        allow(firestore_double).to receive(:toolinfo).and_return([url1, url2])
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(url1).and_return(tool_data)
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(url2).and_return(tool_data)
      end

      it "deduplicates by name and author" do
        result = toolsync.info_array
        expect(result.length).to eq(1)
        expect(result.first.name).to eq("Dupe Tool")
      end
    end
    context "when some toolinfo URLs fail" do
      def stub_fetch(url)
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(url)
      end

      let(:ok_url) { "https://example.com/ok/toolinfo.json" }
      let(:gone_url) { "https://example.com/gone/toolinfo.json" }
      let(:flaky_url) { "https://example.com/flaky/toolinfo.json" }
      let(:broken_json_url) { "https://example.com/broken/toolinfo.json" }
      let(:ok_tool) { { name: "Ok Tool", author: "Author", description: "Test", fileType: "zip", fileURL: "https://example.com/t.zip" } }
      let(:ok_response) { { tools: [ok_tool] } }

      before do
        toolsync.instance_variable_set(:@info_array, nil)
        allow(firestore_double).to receive(:toolinfo).and_return([ok_url, gone_url, flaky_url, broken_json_url])
        stub_fetch(ok_url).and_return(ok_response)
        stub_fetch(gone_url)
          .and_raise(Icarus::Mod::Tools::Sync::RequestGone, "HTTP Request failed for #{gone_url} (404): Not Found")
        stub_fetch(flaky_url)
          .and_raise(Icarus::Mod::Tools::Sync::RequestTransient, "HTTP Request failed for #{flaky_url} (503)")
        stub_fetch(broken_json_url).and_raise(JSON::ParserError, "unexpected token")
      end

      it "remembers which URL each tool came from" do
        result = nil
        expect { result = toolsync.info_array }.to output.to_stderr
        expect(result.map(&:source_url)).to eq([ok_url])
      end

      it "still returns the tools it could read" do
        result = nil
        expect { result = toolsync.info_array }.to output.to_stderr
        expect(result.map(&:name)).to eq(["Ok Tool"])
      end

      it "records transiently failed URLs (including invalid JSON) but not gone ones" do
        expect { toolsync.info_array }.to output.to_stderr
        expect(toolsync.transient_failures).to contain_exactly(flaky_url, broken_json_url)
      end

      it "warns loudly that invalid JSON keeps the existing entries" do
        expect { toolsync.info_array }.to output(/Invalid JSON in #{Regexp.escape(broken_json_url)}.*kept/m).to_stderr
      end

      it "computes the info array before reporting transient failures" do
        expect { expect(toolsync.transient_failures).to contain_exactly(flaky_url, broken_json_url) }.to output.to_stderr
      end
    end

    context "when a toolinfo file has no tools array" do
      def stub_fetch(url)
        allow_any_instance_of(Icarus::Mod::Tools::Sync::Helpers).to receive(:retrieve_from_url).with(url)
      end

      let(:odd_url) { "https://example.com/odd/toolinfo.json" }

      before do
        toolsync.instance_variable_set(:@info_array, nil)
        allow(firestore_double).to receive(:toolinfo).and_return([odd_url])
        stub_fetch(odd_url).and_return({ other: [] })
      end

      it "treats it as malformed (transient) rather than as an empty file" do
        expect { toolsync.info_array }.to output(/#{Regexp.escape(odd_url)}/).to_stderr
        expect(toolsync.transient_failures).to eq([odd_url])
      end

      [
        ["a JSON array", []],
        ["a JSON string", "oops"],
        ["a JSON null", nil],
        ["a tools entry that is not an object", { tools: ["oops"] }]
      ].each do |label, body|
        it "treats #{label} as malformed (transient) instead of aborting the sync" do
          stub_fetch(odd_url).and_return(body)
          expect { toolsync.info_array }.to output(/#{Regexp.escape(odd_url)}/).to_stderr
          expect(toolsync.transient_failures).to eq([odd_url])
        end
      end
    end
  end

  describe "#find" do
    it "calls Firestore.find_by_type with :tool" do
      toolsync.find(toolinfo)

      expect(firestore_double).to have_received(:find_by_type).with(type: "tools", name: "Test Icarus Modding Tool", author: "Test User")
    end
  end

  describe "#find_info" do
    it "returns a Toolinfo object" do
      expect(toolsync.find_info(toolinfo)).to be_a(Icarus::Mod::Tools::Toolinfo)
    end

    context "when tools have the same name but different authors" do
      let(:tool_author1) { Icarus::Mod::Tools::Toolinfo.new({ name: "SharedName", author: "Author1", description: "Test" }) }
      let(:tool_author2) { Icarus::Mod::Tools::Toolinfo.new({ name: "SharedName", author: "Author2", description: "Test" }) }
      let(:search_for_author2) { Icarus::Mod::Tools::Toolinfo.new({ name: "SharedName", author: "Author2", description: "Test" }) }

      before do
        toolsync.instance_variable_set(:@info_array, [tool_author1, tool_author2])
      end

      it "matches by both name AND author, not just name" do
        result = toolsync.find_info(search_for_author2)
        expect(result.author).to eq("Author2")
      end

      it "returns nil when author does not match" do
        nonexistent = Icarus::Mod::Tools::Toolinfo.new({ name: "SharedName", author: "Author3", description: "Test" })
        expect(toolsync.find_info(nonexistent)).to be_nil
      end
    end
  end

  describe "source tracking" do
    before do
      allow(firestore_double).to receive_messages(sources: { "id" => "url" }, save_sources: true, record_source: nil)
    end

    it "#sources reads the tools map" do
      expect(toolsync.sources).to eq("id" => "url")
      expect(firestore_double).to have_received(:sources).with(:tools)
    end

    it "#save_sources saves the tools map" do
      toolsync.save_sources
      expect(firestore_double).to have_received(:save_sources).with(:tools)
    end

    it "#update records the source URL after a successful write" do
      toolinfo.source_url = "https://example.com/toolinfo.json"
      toolinfo.id = "doc-id"
      toolsync.update(toolinfo)
      expect(firestore_double).to have_received(:record_source).with(:tools, "doc-id", "https://example.com/toolinfo.json")
    end

    it "#update records nothing when the write fails" do
      allow(firestore_double).to receive(:update).and_return(false)
      toolinfo.source_url = "https://example.com/toolinfo.json"
      toolsync.update(toolinfo)
      expect(firestore_double).not_to have_received(:record_source)
    end
  end

  describe "#update" do
    it "calls Firestore.update" do
      toolsync.update(toolinfo)

      expect(firestore_double).to have_received(:update).with(:tool, toolinfo, merge: false)
    end
  end

  describe "#delete" do
    it "calls Firestore.delete" do
      toolsync.delete(toolinfo)

      expect(firestore_double).to have_received(:delete).with(:tool, toolinfo)
    end
  end
end
