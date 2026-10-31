# frozen_string_literal: true

require "uri"
require "net/http"
require "json"
require "openssl"

module Icarus
  module Mod
    module Tools
      module Sync
        # Raised when a source URL cannot be read. Subclasses say whether the failure is permanent
        # (RequestGone: the author removed or renamed the file) or may clear up on a later run
        # (RequestTransient). Sync only deletes catalog entries on a permanent failure (#16).
        class RequestFailed < StandardError
          def transient?
            false
          end
        end

        # The source is gone (HTTP 404 or 410): its entries may be removed from the catalog
        class RequestGone < RequestFailed; end

        # The source could not be read this run (timeout, network/DNS/TLS error, 5xx, 403/429 rate limits,
        # or any other unexpected status): its entries must be kept until a run can read it again
        class RequestTransient < RequestFailed
          def transient?
            true
          end
        end

        # Sync helper methods
        module Helpers
          GONE_STATUS_CODES = %w[404 410].freeze

          # Errors raised by Net::HTTP for a request that never got a usable response
          NETWORK_ERRORS = [Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError].freeze

          def retrieve_from_url(url)
            raise RequestFailed, "Invalid URI: '#{url}'" unless url && url =~ URI::DEFAULT_PARSER.make_regexp

            uri = begin
              URI(url)
            rescue URI::InvalidURIError
              raise RequestFailed, "Invalid URI: '#{url}'"
            end
            http = Net::HTTP.new(uri.host, uri.port)

            if uri.scheme == "https"
              http.use_ssl = true
              http.verify_mode = OpenSSL::SSL::VERIFY_PEER
              # Disable CRL checking which is causing the issue
              http.verify_callback = proc { |preverify_ok, ssl_context|
                if ssl_context.error == OpenSSL::X509::V_ERR_UNABLE_TO_GET_CRL
                  true
                else
                  preverify_ok
                end
              }
            end

            res = begin
              http.get(uri.request_uri)
            rescue *NETWORK_ERRORS => e
              raise RequestTransient, "HTTP Request failed for #{url} (#{e.class}): #{e.message}"
            end

            unless res&.code == "200"
              error_class = GONE_STATUS_CODES.include?(res&.code) ? RequestGone : RequestTransient
              raise error_class, "HTTP Request failed for #{url} (#{res&.code}): #{res&.message}"
            end

            JSON.parse(res.body, symbolize_names: true)
          end
        end
      end
    end
  end
end
