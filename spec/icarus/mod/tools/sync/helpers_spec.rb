require "tools/sync/helpers"
require "uri"
require "json"

RSpec.describe Icarus::Mod::Tools::Sync::Helpers do
  subject(:sync_helpers) { Object.new.extend(described_class) }

  let(:success_response) { instance_double(Net::HTTPSuccess, code: "200", message: "OK", body: modinfo_json) }
  let(:failure_response) { instance_double(Net::HTTPNotFound, code: "404", message: "Not Found") }
  let(:http_client) { instance_double(Net::HTTP) }

  it { is_expected.to respond_to(:retrieve_from_url) }

  describe "#retrieve_from_url" do
    let(:url) { "https://raw.githubusercontent.com/Donovan522/Icarus-Mods/main/modinfo.json" }
    let(:uri) { URI(url) }
    let(:modinfo_json) { File.read("spec/fixtures/modinfo.json") }
    let(:modinfo_array) { JSON.parse(modinfo_json, symbolize_names: true) }

    before do
      allow(Net::HTTP).to receive(:new).with(uri.host, uri.port).and_return(http_client)
      allow(http_client).to receive(:use_ssl=)
      allow(http_client).to receive(:verify_mode=)
      allow(http_client).to receive(:verify_callback=)
    end

    context "when the URL is valid" do
      before do
        allow(http_client).to receive(:get).with(uri.path).and_return(success_response)
      end

      it "returns valid JSON data" do
        expect(sync_helpers.retrieve_from_url(url)).to eq(modinfo_array)
      end
    end

    context "when the URL is invalid" do
      before do
        allow(http_client).to receive(:get).with(uri.path).and_return(failure_response)
      end

      it "raises an error" do
        expect { sync_helpers.retrieve_from_url(url) }
          .to raise_error(Icarus::Mod::Tools::Sync::RequestFailed, "HTTP Request failed for #{url} (404): Not Found")
      end
    end

    context "when the URL is not a valid URI" do
      it "raises an Invalid URI error" do
        expect { sync_helpers.retrieve_from_url("foo") }
          .to raise_error(Icarus::Mod::Tools::Sync::RequestFailed, "Invalid URI: 'foo'")
      end
    end

    context "when the URL is nil" do
      it "raises an Invalid URI error" do
        expect { sync_helpers.retrieve_from_url(nil) }
          .to raise_error(Icarus::Mod::Tools::Sync::RequestFailed, "Invalid URI: ''")
      end
    end
  end
end
