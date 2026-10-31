# frozen_string_literal: true

require "ipaddr"
require "resolv"
require "uri"
require "net/http"
require "tools/sync/helpers"

module Icarus
  module Mod
    module Tools
      # Requests a URL (following redirects) without downloading it, to see where it ends up
      class LinkProbe
        MAX_REDIRECTS = 5
        REDIRECT_CODES = [301, 302, 303, 307, 308].freeze
        # Statuses that mean "HEAD is not allowed here", so try a ranged GET instead
        HEAD_REFUSED = [403, 405, 501].freeze
        OK_STATUSES = [200, 206].freeze

        # Links come from a stranger's modinfo.json and are probed from the maintainer's network, and the status
        # ends up in a public comment: never request loopback, private, link-local or other non-public addresses
        NON_PUBLIC = %w[0.0.0.0/8 100.64.0.0/10 192.0.0.0/24 198.18.0.0/15 224.0.0.0/3 ::/128 64:ff9b::/96 ff00::/8]
                     .map { |range| IPAddr.new(range) }.freeze

        # http: a callable (uri, verb, ip) -> [status, location]; resolver: a callable (host) -> [addresses].
        # Both are replaceable so specs need no network.
        def initialize(http: nil, resolver: nil)
          @http = http || method(:net_request)
          @resolver = resolver || Resolv.method(:getaddresses)
        end

        def self.github_host?(host)
          host == "github.com" || host.to_s.end_with?(".github.com") || host == "githubusercontent.com" ||
            host.to_s.end_with?(".githubusercontent.com")
        end

        # Follows up to MAX_REDIRECTS redirects; returns [status, final_host, problem]
        def call(url)
          uri = URI.parse(url)
          status = nil
          (MAX_REDIRECTS + 1).times do
            status, location, refused = hop(uri)
            return [status, uri.host, refused] if refused || !(REDIRECT_CODES.include?(status) && location)

            uri = URI.join(uri, location)
          end
          [status, uri.host, "too many redirects (more than #{MAX_REDIRECTS})"]
        rescue URI::Error, *Sync::Helpers::NETWORK_ERRORS => e
          [nil, nil, "request failed (#{e.message})"]
        end

        private

        # One request, after checking where it would go: [status, location] or [nil, nil, refusal]
        def hop(uri)
          ips, refused = public_addresses(uri)
          refused ? [nil, nil, refused] : request(uri, ips)
        end

        # The addresses to connect to (IPv4 first), or a reason to refuse. Every address the host resolves to must be
        # public, and the request then goes to a checked address, so a DNS answer that changes in between cannot
        # redirect it.
        def public_addresses(uri)
          return [nil, "refused: only http and https links are checked"] unless %w[http https].include?(uri.scheme)

          host = uri.hostname
          addresses = ip_literal?(host) ? [host] : @resolver.call(host)
          return [nil, "refused: #{uri.host} does not resolve"] if addresses.empty?
          return [nil, "refused: #{uri.host} resolves to a non-public address"] unless addresses.all? { |a| public_ip?(a) }

          [addresses.partition { |a| IPAddr.new(a).ipv4? }.flatten, nil]
        end

        def ip_literal?(host)
          IPAddr.new(host)
          true
        rescue IPAddr::InvalidAddressError
          false
        end

        def public_ip?(address)
          ip = IPAddr.new(address)
          ip = ip.native if ip.ipv4_mapped?
          !(ip.private? || ip.loopback? || ip.link_local? || NON_PUBLIC.any? { |range| range.include?(ip) })
        rescue IPAddr::InvalidAddressError
          false
        end

        # HEAD, then a one-byte ranged GET if HEAD is refused. An unreachable address (no IPv6 route, say) falls back
        # to the next checked one; the last failure propagates.
        def request(uri, ips)
          ips.each_with_index do |ip, index|
            result = @http.call(uri, "HEAD", ip)
            return HEAD_REFUSED.include?(result.first) ? @http.call(uri, "GET", ip) : result
          rescue *Sync::Helpers::NETWORK_ERRORS
            raise if index == ips.size - 1
          end
        end

        def net_request(uri, verb, ip)
          req = verb == "GET" ? Net::HTTP::Get.new(uri.request_uri, "Range" => "bytes=0-0") : Net::HTTP::Head.new(uri.request_uri)
          # Yield from the block so a server that ignores Range never has its whole body downloaded
          connection(uri, ip).start { |conn| conn.request(req) { |res| return [res.code.to_i, res["location"]] } }
        end

        def connection(uri, ip)
          Net::HTTP.new(uri.host, uri.port).tap do |http|
            http.ipaddr = ip
            http.use_ssl = uri.scheme == "https"
            http.open_timeout = http.read_timeout = 15
          end
        end
      end
    end
  end
end
