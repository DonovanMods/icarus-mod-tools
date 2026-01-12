# frozen_string_literal: true

module Icarus
  module Mod
    module Tools
      # Base class for Modinfo and Toolinfo
      class Baseinfo
        attr_reader :data, :id, :created_at, :updated_at

        HASHKEYS = %i[name author version compatibility description files imageURL readmeURL].freeze

        # Match github.com URLs with /blob/ or /raw/ and convert to raw.githubusercontent.com
        GITHUB_BLOB_RAW_URL_PATTERN = %r{
          (https?)://(?:www\.)?github\.com/  # Protocol and GitHub domain (capture group 1)
          ([^/]+)/                            # owner (capture group 2)
          ([^/]+)/                            # repo (capture group 3)
          (?:blob|raw)/                       # /blob/ or /raw/ to remove
          (.+)                                # branch and file path (capture group 4)
        }x

        def initialize(data, id: nil, created: nil, updated: nil)
          @id = id
          @created_at = created
          @updated_at = updated
          @errors = []
          @warnings = []
          @validated = false

          read(data)
        end

        def author_id
          author.downcase.gsub(/\s+/, "_")
        end

        def read(data)
          @data = data.is_a?(String) ? JSON.parse(data, symbolize_names: true) : data
          normalize_github_urls_in_data
          @data
        end

        def errors
          validate
          @errors.compact.uniq
        end

        def errors?
          errors.any?
        end

        def warnings
          validate
          @warnings.compact.uniq
        end

        def warnings?
          warnings.any?
        end

        def status
          validate

          {
            errors:,
            warnings:
          }
        end

        def uniq_name
          "#{author.strip}/#{name.strip}"
        end

        def to_json(*args)
          JSON.generate(@data, *args)
        end

        def to_h
          db_hash = HASHKEYS.each_with_object({}) { |key, hash| hash[key] = @data[key] }

          db_hash[:version] = "1.0" if version.nil?

          db_hash
        end

        def validate
          return true if @validated

          validate_version

          %w[name author description].each do |key|
            @errors << "#{key.capitalize} cannot be blank" unless validate_string(@data[key.to_sym])
          end

          %w[imageURL readmeURL].each do |key|
            @errors << "Invalid URL #{key.capitalize}: #{@data[key.to_sym] || "blank"}" unless validate_url(@data[key.to_sym])
          end

          @validated = true
        end

        def valid?
          validate

          !errors?
        end

        def file_types
          files&.keys || []
        end

        def file_urls
          files&.values || []
        end

        def method_missing(method_name, *_args, &_block)
          @data[method_name.to_sym] if @data.key?(method_name.to_sym)
        end

        def respond_to_missing?(method_name, include_private = false)
          @data.key?(method_name.to_sym) || super
        end

        private

        def filetype_pattern
          /(zip|pak|exmodz?)/i
        end

        def validate_string(string)
          !(string.nil? || string.empty?)
        end

        def validate_url(url)
          return true if url.nil? || url.empty?

          url =~ URI::DEFAULT_PARSER.make_regexp
        end

        def validate_files
          @warnings << "This mod uses deprecated fields (fileType and fileURL)" if @data.key?(:fileType) || @data.key?(:fileURL)
          @warnings << "files should not be empty" if file_types.empty?

          file_types.each { |file_type| validate_filetype(file_type) }

          file_urls.each do |file_url|
            @errors << "Invalid URL: #{file_url}" unless validate_url(file_url)
          end
        end

        def validate_filetype(file_type)
          @errors << "Invalid fileType: #{file_type.upcase}" unless file_type&.match?(filetype_pattern)
        end

        def validate_version
          if version.nil?
            @warnings << "Version was nil, it has been defaulted to 1.0"
          else
            @warnings << "Version should be a version string" unless /^\d+[.\d+]*/.match?(version)
          end
        end

        def normalize_github_url(url)
          return url if url.nil? || url.empty?

          if url.match?(GITHUB_BLOB_RAW_URL_PATTERN)
            normalized = url.gsub(GITHUB_BLOB_RAW_URL_PATTERN, '\1://raw.githubusercontent.com/\2/\3/\4')
            @warnings << "GitHub URL converted to raw.githubusercontent.com format for direct download. Auto-fixed: #{url}"
            normalized
          else
            url
          end
        end

        def normalize_github_urls_in_data
          @data[:imageURL] = normalize_github_url(@data[:imageURL])
          @data[:readmeURL] = normalize_github_url(@data[:readmeURL])
        end
      end
    end
  end
end
