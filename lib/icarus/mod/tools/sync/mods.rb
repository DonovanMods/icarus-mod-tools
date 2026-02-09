# frozen_string_literal: true

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

          def info_array
            @info_array ||= @firestore.modinfo.map do |url|
              retrieve_from_url(url)[:mods].map { |mod| Icarus::Mod::Tools::Modinfo.new(mod) if /[a-z0-9]+/i.match?(mod[:name]) }
            rescue Icarus::Mod::Tools::Sync::RequestFailed
              warn "Skipped; Failed to retrieve #{url}"
              next
            rescue JSON::ParserError => e
              warn "Skipped; Invalid JSON in #{url}: #{e.message}"
              next
            end.flatten.compact.uniq { |mod| [mod.name, mod.author] }
          end

          def find(modinfo)
            @firestore.find_by_type(type: "mods", name: modinfo.name, author: modinfo.author)&.id
          end

          def find_info(modinfo)
            @info_array.find { |mod| mod.name == modinfo.name }
          end

          def update(modinfo)
            @firestore.update(:mod, modinfo, merge: false)
          end

          def delete(modinfo)
            @firestore.delete(:mod, modinfo)
          end
        end
      end
    end
  end
end
