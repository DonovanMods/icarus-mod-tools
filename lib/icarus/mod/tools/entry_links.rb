# frozen_string_literal: true

require "uri"
require "tools/modinfo"

module Icarus
  module Mod
    module Tools
      # The links inside a Modinfo/Toolinfo entry that RepoCheck probes
      module EntryLinks
        module_function

        # [field, url, download?] for every non-blank string link in the entry
        def for(info)
          links = info.is_a?(Modinfo) ? mod_links(info) : [["fileURL", info.fileURL, true]]
          links += [["imageURL", info.imageURL, false], ["readmeURL", info.readmeURL, false]]
          links.select { |_, url, _| url.is_a?(String) && !url.strip.empty? }
        end

        def mod_links(info)
          info.file_urls.zip(info.file_types).map { |url, name| ["files.#{name}", url, true] }
        end

        def windows_tool?(info)
          info.fileType.to_s.match?(/\A\.?exe\z/i) || URI.parse(info.fileURL.to_s).path.to_s.match?(/\.exe\z/i)
        rescue URI::InvalidURIError
          false
        end
      end
    end
  end
end
