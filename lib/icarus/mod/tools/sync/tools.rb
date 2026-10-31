# frozen_string_literal: true

require "tools/sync/entities"

module Icarus
  module Mod
    module Tools
      module Sync
        # Syncs meta/toolinfo to the tools collection (see Entities)
        class Tools < Entities
          TYPE = :tool
          INFO = :toolinfo
          ENTITY = Icarus::Mod::Tools::Toolinfo

          def tools
            @firestore.tools
          end
        end
      end
    end
  end
end
