# frozen_string_literal: true

require "paint"
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

          # Every tool we could read from the toolinfo URLs this run. URLs that failed transiently
          # (see #transient_failures) contribute nothing here, so their tools must not be deleted.
          def info_array
            return @info_array if @info_array

            @transient_failures = []
            @info_array = @firestore.toolinfo.map do |url|
              next unless url

              tools_from(url)
            rescue Icarus::Mod::Tools::Sync::RequestFailed => e
              @transient_failures << url if e.transient?
              warn "Skipped; Failed to retrieve #{url}#{' (transient; its existing entries are kept)' if e.transient?}"
              next
            rescue JSON::ParserError => e
              @transient_failures << url
              warn Paint["WARNING: Skipped; Invalid JSON in #{url}: #{e.message}", :red, :bright]
              warn Paint["WARNING: Existing entries from #{url} are kept until it parses again; " \
                         "remove or rename the file to remove them", :red, :bright]
              next
            end.flatten.compact.uniq { |tool| [tool.name, tool.author] }
          end

          # The toolinfo URLs that could not be read this run for a reason that may clear up
          # (network error, 5xx, rate limit, invalid JSON). Gone (404/410) URLs are not included.
          def transient_failures
            info_array
            @transient_failures || []
          end

          def find(toolinfo)
            @firestore.find_by_type(type: "tools", name: toolinfo.name, author: toolinfo.author)&.id
          end

          def find_info(toolinfo)
            @info_array.find { |tool| tool.name == toolinfo.name && tool.author == toolinfo.author }
          end

          def update(toolinfo)
            success = @firestore.update(:tool, toolinfo, merge: false)
            @firestore.record_source(:tools, toolinfo.id, toolinfo.source_url) if success && toolinfo.source_url

            success
          end

          # doc ID => toolinfo URL it was last synced from (see Firestore#sources)
          def sources
            @firestore.sources(:tools)
          end

          def save_sources
            @firestore.save_sources(:tools)
          end

          def delete(toolinfo)
            @firestore.delete(:tool, toolinfo)
          end

          private

          def tools_from(url)
            tools = retrieve_from_url(url)[:tools]
            raise JSON::ParserError, "no 'tools' array" unless tools.is_a?(Array)

            tools.filter_map do |data|
              next unless /[a-z0-9]+/i.match?(data[:name])

              Icarus::Mod::Tools::Toolinfo.new(data).tap { |tool| tool.source_url = url }
            end
          end
        end
      end
    end
  end
end
