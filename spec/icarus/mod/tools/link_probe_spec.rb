# frozen_string_literal: true

require "tools/link_probe"

RSpec.describe Icarus::Mod::Tools::LinkProbe do
  subject(:probe) { described_class.new(http:, resolver:) }

  let(:requests) { [] }
  let(:http) do
    lambda do |uri, verb, ip|
      requests << [uri.to_s, verb, ip]
      [200, nil]
    end
  end
  let(:addresses) { { "example.com" => ["93.184.216.34"] } }
  let(:resolver) { ->(host) { addresses.fetch(host, []) } }

  it "requests a public host, connecting to the address it checked" do
    expect(probe.call("https://example.com/a.pak")).to eq([200, "example.com", nil])
    expect(requests).to eq([["https://example.com/a.pak", "HEAD", "93.184.216.34"]])
  end

  {
    "loopback" => "127.0.0.1",
    "a private network" => "192.168.1.1",
    "link-local (cloud metadata)" => "169.254.169.254",
    "this network" => "0.0.0.0",
    "carrier-grade NAT" => "100.64.0.1",
    "IPv6 loopback" => "::1",
    "IPv6 unique-local" => "fd00::1"
  }.each do |label, address|
    it "refuses a host that resolves to #{label} without requesting it" do
      addresses["internal.example"] = [address]
      status, _host, problem = probe.call("https://internal.example/x")
      expect(status).to be_nil
      expect(problem).to include("non-public address")
      expect(requests).to be_empty
    end
  end

  it "tries IPv4 first and falls back to the next checked address when one is unreachable" do
    addresses["dual.example"] = ["2606:50c0:8001::154", "185.199.109.133", "185.199.108.133"]
    flaky = lambda do |uri, verb, ip|
      requests << [uri.to_s, verb, ip]
      raise Errno::ENETUNREACH if ip == "185.199.109.133"

      [200, nil]
    end
    expect(described_class.new(http: flaky, resolver:).call("https://dual.example/a").first).to eq(200)
    expect(requests.map(&:last)).to eq(["185.199.109.133", "185.199.108.133"])
  end

  it "reports the failure when no checked address can be reached" do
    addresses["down.example"] = ["185.199.109.133"]
    down = ->(_uri, _verb, _ip) { raise Errno::ENETUNREACH }
    expect(described_class.new(http: down, resolver:).call("https://down.example/a").last).to include("request failed")
  end

  it "refuses a host when any of its addresses is non-public" do
    addresses["mixed.example"] = ["93.184.216.34", "10.0.0.5"]
    expect(probe.call("https://mixed.example/x").last).to include("non-public address")
    expect(requests).to be_empty
  end

  it "refuses an IP literal on a private network" do
    expect(probe.call("http://10.1.2.3/x").last).to include("non-public address")
    expect(requests).to be_empty
  end

  it "refuses a redirect to a non-public host" do
    addresses["internal.example"] = ["127.0.0.1"]
    redirecting = lambda do |uri, verb, ip|
      requests << [uri.to_s, verb, ip]
      uri.host == "example.com" ? [302, "https://internal.example/admin"] : [200, nil]
    end
    status, _host, problem = described_class.new(http: redirecting, resolver:).call("https://example.com/a")
    expect([status, problem]).to match([nil, /non-public address/])
    expect(requests.map(&:first)).to eq(["https://example.com/a"])
  end

  it "refuses a host that does not resolve" do
    expect(probe.call("https://nowhere.example/x").last).to include("does not resolve")
  end

  it "refuses schemes other than http and https" do
    expect(probe.call("ftp://example.com/a.pak").last).to include("only http")
    expect(requests).to be_empty
  end
end
