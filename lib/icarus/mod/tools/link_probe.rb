# frozen_string_literal: true

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

        # http: a callable (uri, verb) -> [status, location]; replaceable so specs need no network
        def initialize(http: nil)
          @http = http || method(:net_request)
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
            status, location = request(uri)
            return [status, uri.host, nil] unless REDIRECT_CODES.include?(status) && location

            uri = URI.join(uri, location)
          end
          [status, uri.host, "too many redirects (more than #{MAX_REDIRECTS})"]
        rescue URI::Error, *Sync::Helpers::NETWORK_ERRORS => e
          [nil, nil, "request failed (#{e.message})"]
        end

        private

        # HEAD, then a one-byte ranged GET if HEAD is refused
        def request(uri)
          result = @http.call(uri, "HEAD")
          HEAD_REFUSED.include?(result.first) ? @http.call(uri, "GET") : result
        end

        def net_request(uri, verb)
          req = verb == "GET" ? Net::HTTP::Get.new(uri.request_uri, "Range" => "bytes=0-0") : Net::HTTP::Head.new(uri.request_uri)
          # Yield from the block so a server that ignores Range never has its whole body downloaded
          connection(uri).start { |conn| conn.request(req) { |res| return [res.code.to_i, res["location"]] } }
        end

        def connection(uri)
          Net::HTTP.new(uri.host, uri.port).tap do |http|
            http.use_ssl = uri.scheme == "https"
            http.open_timeout = http.read_timeout = 15
          end
        end
      end
    end
  end
end
