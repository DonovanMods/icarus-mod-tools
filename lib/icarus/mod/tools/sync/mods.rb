# frozen_string_literal: true

require "paint"
require "firestore"
require "tools/sync/helpers"

module Icarus
  module Mod
    module Tools
      module Sync
        # Sync methods
        class Mods
          include Helpers

          def initialize(client: nil)
            @firestore = client || Firestore.new
          end

          def mods
            @firestore.mods
          end

          # Every mod we could read from the modinfo URLs this run. URLs that failed transiently
          # (see #transient_failures) contribute nothing here, so their mods must not be deleted.
          def info_array
            return @info_array if @info_array

            @transient_failures = []
            @info_array = @firestore.modinfo.map do |url|
              mods_from(url)
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
            end.flatten.compact.uniq { |mod| [mod.name, mod.author] }
          end

          # The modinfo URLs that could not be read this run for a reason that may clear up
          # (network error, 5xx, rate limit, invalid JSON). Gone (404/410) URLs are not included.
          def transient_failures
            info_array
            @transient_failures || []
          end

          def find(modinfo)
            @firestore.find_by_type(type: "mods", name: modinfo.name, author: modinfo.author)&.id
          end

          def find_info(modinfo)
            @info_array.find { |mod| mod.name == modinfo.name && mod.author == modinfo.author }
          end

          def update(modinfo)
            success = @firestore.update(:mod, modinfo, merge: false)
            @firestore.record_source(:mods, modinfo.id, modinfo.source_url) if success && modinfo.source_url

            success
          end

          # doc ID => modinfo URL it was last synced from (see Firestore#sources)
          def sources
            @firestore.sources(:mods)
          end

          def save_sources
            @firestore.save_sources(:mods)
          end

          def delete(modinfo)
            @firestore.delete(:mod, modinfo)
          end

          private

          def mods_from(url)
            mods = retrieve_from_url(url)[:mods]
            raise JSON::ParserError, "no 'mods' array" unless mods.is_a?(Array)

            mods.filter_map do |data|
              next unless /[a-z0-9]+/i.match?(data[:name])

              Icarus::Mod::Tools::Modinfo.new(data).tap { |mod| mod.source_url = url }
            end
          end
        end
      end
    end
  end
end
