# frozen_string_literal: true

require "tools/baseinfo"

module Icarus
  module Mod
    module Tools
      # Sync methods
      class Modinfo < Baseinfo
        def to_h
          db_hash = super
          db_hash[:meta] = {status:} # Add metadata

          db_hash
        end

        def validate
          return true if @validated

          validate_files

          super
        end

        private

        def normalize_github_urls_in_data
          super # Handle imageURL and readmeURL

          # Skip normalization if data is frozen (e.g., from Firestore)
          return if @data.frozen?

          # Normalize each file URL in the files hash
          return unless @data[:files].is_a?(Hash)

          @data[:files].transform_values! do |url|
            normalize_github_url(url)
          end
        end
      end
    end
  end
end
