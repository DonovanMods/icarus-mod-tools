# frozen_string_literal: true

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

    context "when the classification of a failure matters" do
      def failure_for(code, message = "Error")
        response = instance_double(Net::HTTPResponse, code: code, message: message)
        allow(http_client).to receive(:get).with(uri.path).and_return(response)
        sync_helpers.retrieve_from_url(url)
      rescue Icarus::Mod::Tools::Sync::RequestFailed => e
        e
      end

      %w[404 410].each do |code|
        it "treats HTTP #{code} as gone" do
          error = failure_for(code)
          expect(error).to be_a(Icarus::Mod::Tools::Sync::RequestGone)
          expect(error).not_to be_transient
        end
      end

      %w[500 502 503 403 429 301 400].each do |code|
        it "treats HTTP #{code} as transient" do
          error = failure_for(code)
          expect(error).to be_a(Icarus::Mod::Tools::Sync::RequestTransient)
          expect(error).to be_transient
          expect(error.message).to include(url, code)
        end
      end

      [
        Net::OpenTimeout.new("execution expired"),
        Net::ReadTimeout.new,
        SocketError.new("getaddrinfo: Name or service not known"),
        Errno::ECONNREFUSED.new,
        Errno::ECONNRESET.new,
        OpenSSL::SSL::SSLError.new("certificate verify failed"),
        EOFError.new("end of file reached")
      ].each do |exception|
        it "wraps #{exception.class} as a transient failure naming the URL" do
          allow(http_client).to receive(:get).with(uri.path).and_raise(exception)

          expect { sync_helpers.retrieve_from_url(url) }
            .to(raise_error(Icarus::Mod::Tools::Sync::RequestTransient) do |error|
              expect(error.message).to include(url)
              expect(error).to be_transient
            end)
        end
      end
    end

    context "when the URL is not a valid URI" do
      it "raises an Invalid URI error" do
        expect { sync_helpers.retrieve_from_url("foo") }
          .to raise_error(Icarus::Mod::Tools::Sync::RequestFailed, "Invalid URI: 'foo'")
      end

      it "is not transient (a malformed list entry cannot recover by retrying)" do
        expect { sync_helpers.retrieve_from_url("foo") }
          .to(raise_error(Icarus::Mod::Tools::Sync::RequestFailed) { |error| expect(error).not_to be_transient })
      end
    end

    context "when the URL has a query string" do
      let(:url) { "https://raw.githubusercontent.com/Donovan522/Icarus-Mods/main/modinfo.json?token=abc" }

      it "requests the path with its query" do
        allow(http_client).to receive(:get).with("/Donovan522/Icarus-Mods/main/modinfo.json?token=abc").and_return(success_response)
        expect(sync_helpers.retrieve_from_url(url)).to eq(modinfo_array)
      end
    end

    context "when the URL passes the loose URI check but cannot be parsed" do
      it "raises a non-transient Invalid URI error instead of crashing" do
        expect { sync_helpers.retrieve_from_url("see https://example.com/modinfo.json") }
          .to(raise_error(Icarus::Mod::Tools::Sync::RequestFailed, /Invalid URI/) { |error| expect(error).not_to be_transient })
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
