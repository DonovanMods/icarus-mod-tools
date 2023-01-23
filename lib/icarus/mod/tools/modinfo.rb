# frozen_string_literal: true

require "tools/baseinfo"

module Icarus
  module Mod
    module Tools
      # Sync methods
      class Modinfo < Baseinfo
        HASHKEYS = %i[name author version compatibility description long_description fileType fileURL imageURL readmeURL].freeze

        # rubocop:disable Naming/MethodName
        def fileType
          @data[:fileType] || "pak"
        end
        # rubocop:enable Naming/MethodName
      end
    end
  end
end
