# frozen_string_literal: true

require "firestore"
require "tools/sync/helpers"

module Icarus
  module Mod
    module Tools
      module Sync
        # Sync methods
        class Tools
          include Helpers

          def initialize(client: nil)
            @firestore = client || Firestore.new
          end

          def tools
            @firestore.tools
          end

          def info_array
            @info_array ||= @firestore.toolinfo.map do |url|
              next unless url

              retrieve_from_url(url)[:tools].map { |tool| Icarus::Mod::Tools::Toolinfo.new(tool) if /[a-z0-9]+/i.match?(tool[:name]) }
            rescue Icarus::Mod::Tools::Sync::RequestFailed
              warn "Skipped; Failed to retrieve #{url}"
              next
            rescue JSON::ParserError => e
              warn "Skipped; Invalid JSON: #{e.message}"
              next
            end.flatten.compact
          end

          def find(toolinfo)
            @firestore.find_by_type(type: "tools", name: toolinfo.name, author: toolinfo.author)&.id
          end

          def find_info(toolinfo)
            @info_array.find { |tool| tool.name == toolinfo.name }
          end

          def update(toolinfo)
            @firestore.update(:tool, toolinfo, merge: false)
          end

          def delete(toolinfo)
            @firestore.delete(:tool, toolinfo)
          end
        end
      end
    end
  end
end
