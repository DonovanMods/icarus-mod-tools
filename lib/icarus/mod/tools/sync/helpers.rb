# frozen_string_literal: true

require "uri"
require "net/http"
require "json"
require "openssl"

module Icarus
  module Mod
    module Tools
      module Sync
        class RequestFailed < StandardError; end

        # Sync helper methods
        module Helpers
          def retrieve_from_url(url)
            raise RequestFailed, "Invalid URI: '#{url}'" unless url && url =~ URI::DEFAULT_PARSER.make_regexp

            uri = URI(url)
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

            res = http.get(uri.path.empty? ? "/" : uri.path)

            raise RequestFailed, "HTTP Request failed for #{url} (#{res.code}): #{res.message}" unless res&.code == "200"

            JSON.parse(res.body, symbolize_names: true)
          end
        end
      end
    end
  end
end
