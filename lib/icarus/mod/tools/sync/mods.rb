# frozen_string_literal: true

require "tools/sync/entities"

module Icarus
  module Mod
    module Tools
      module Sync
        # Syncs meta/modinfo to the mods collection (see Entities)
        class Mods < Entities
          TYPE = :mod
          INFO = :modinfo
          ENTITY = Icarus::Mod::Tools::Modinfo

          def mods
            @firestore.mods
          end
        end
      end
    end
  end
end
