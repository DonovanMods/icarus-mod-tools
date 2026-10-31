# frozen_string_literal: true

require "paint"
require "firestore"
require "tools/sync/helpers"

module Icarus
  module Mod
    module Tools
      module Sync
        # Shared meta/modinfo -> mods and meta/toolinfo -> tools sync. Subclasses set TYPE (:mod or :tool),
        # INFO (:modinfo or :toolinfo) and ENTITY (the Modinfo or Toolinfo class).
        class Entities
          include Helpers

          def initialize(client: nil)
            @firestore = client || Firestore.new
          end

          # Every entry we could read from the info URLs this run. URLs that failed transiently
          # (see #transient_failures) contribute nothing here, so their entries must not be deleted.
          def info_array
            return @info_array if @info_array

            @transient_failures = []
            @info_array = @firestore.send(self.class::INFO).map do |url|
              next unless url

              entries_from(url)
            rescue Icarus::Mod::Tools::Sync::RequestFailed => e
              @transient_failures << url if e.transient?
              warn "Skipped; Failed to retrieve #{url}#{" (transient; its existing entries are kept)" if e.transient?}"
              next
            rescue JSON::ParserError => e
              @transient_failures << url
              warn Paint["WARNING: Skipped; Invalid JSON in #{url}: #{e.message}", :red, :bright]
              warn Paint["WARNING: Existing entries from #{url} are kept until it parses again; " \
                         "remove or rename the file to remove them", :red, :bright]
              next
            end.flatten.compact.uniq { |entry| [entry.name, entry.author] }
          end

          # The info URLs that could not be read this run for a reason that may clear up
          # (network error, 5xx, rate limit, invalid JSON). Gone (404/410) URLs are not included.
          def transient_failures
            info_array
            @transient_failures || []
          end

          def find(info)
            @firestore.find_by_type(type: plural.to_s, name: info.name, author: info.author)&.id
          end

          def find_info(info)
            @info_array.find { |entry| entry.name == info.name && entry.author == info.author }
          end

          def update(info)
            success = @firestore.update(self.class::TYPE, info, merge: false)
            @firestore.record_source(plural, info.id, info.source_url) if success && info.source_url

            success
          end

          # doc ID => info URL it was last synced from (see Firestore#sources)
          def sources
            @firestore.sources(plural)
          end

          def save_sources
            @firestore.save_sources(plural)
          end

          def delete(info)
            @firestore.delete(self.class::TYPE, info)
          end

          private

          def plural
            :"#{self.class::TYPE}s"
          end

          # A body that is not a JSON object, or an entry that is not one, is treated as invalid JSON
          # (transient), so one malformed file cannot abort the whole sync
          def entries_from(url)
            body = retrieve_from_url(url)
            entries = body[plural] if body.is_a?(Hash)
            raise JSON::ParserError, "no '#{plural}' array" unless entries.is_a?(Array)
            raise JSON::ParserError, "'#{plural}' entries must be objects" unless entries.all?(Hash)

            entries.filter_map do |data|
              next unless data[:name].is_a?(String) && /[a-z0-9]+/i.match?(data[:name])

              self.class::ENTITY.new(data).tap { |entry| entry.source_url = url }
            end
          end
        end
      end
    end
  end
end
