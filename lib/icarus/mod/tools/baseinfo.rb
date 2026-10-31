# frozen_string_literal: true

require "uri"

module Icarus
  module Mod
    module Tools
      # Base class for Modinfo and Toolinfo
      class Baseinfo
        attr_reader :data
        attr_accessor :id, :created_at, :updated_at
        # The modinfo/toolinfo URL this entry was read from during sync; never written to the entry's doc
        attr_accessor :source_url

        HASHKEYS = %i[name author version compatibility description files imageURL readmeURL].freeze

        # Appended to warnings for input the stricter rules reject but the old ones accepted
        FUTURE_ERROR = "(this will become an error in a future release)"

        # Keys that may be read through method_missing even when absent from the data
        EXTRA_KEYS = %i[files fileType fileURL].freeze

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
          author.to_s.downcase.gsub(/\s+/, "_")
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
          "#{author.to_s.strip}/#{name.to_s.strip}"
        end

        def to_json(*)
          JSON.generate(@data, *)
        end

        def to_h
          db_hash = HASHKEYS.each_with_object({}) { |key, hash| hash[key] = @data[key] }

          db_hash[:version] = "1.0" if version.nil?
          db_hash[:files] = db_hash[:files]&.reject { |_, url| url.nil? || url.to_s.strip.empty? }

          db_hash
        end

        def validate
          return true if @validated

          validate_version

          %w[name author description].each do |key|
            validate_required_string(key, @data[key.to_sym])
          end

          %w[imageURL readmeURL].each do |key|
            check_url(@data[key.to_sym], "Invalid URL #{key.capitalize}: #{@data[key.to_sym] || "blank"}")
          end

          @validated = true
        end

        def valid?
          validate

          !errors?
        end

        def file_types
          files.is_a?(Hash) ? files.keys : []
        end

        def file_urls
          files.is_a?(Hash) ? files.values : []
        end

        # Firestore#update guards its payload with #empty?
        def empty?
          @data.nil? || @data.empty?
        end

        # Data keys and known fields read as nil when absent; any other name (a typo) raises
        def method_missing(method_name, *args, &)
          return super unless known_key?(method_name)

          @data[method_name.to_sym]
        end

        def respond_to_missing?(method_name, include_private = false)
          known_key?(method_name) || super
        end

        private

        def known_key?(method_name)
          return false if method_name.to_s.end_with?("=", "?", "!")

          @data.key?(method_name.to_sym) || self.class::HASHKEYS.include?(method_name.to_sym) || EXTRA_KEYS.include?(method_name.to_sym)
        end

        # The file type must be exactly one of these, with an optional leading dot
        def filetype_pattern
          /\A\.?(zip|pak|exmodz?)\z/i
        end

        # The previous, unanchored rule; a match here but not above is only a warning for now
        def legacy_filetype_pattern
          /(zip|pak|exmodz?)/i
        end

        def validate_required_string(key, value)
          if value.nil? || value == ""
            @errors << "#{key.capitalize} cannot be blank"
          elsif !value.is_a?(String)
            @errors << "#{key.capitalize} must be a string"
          end
        end

        # :ok, :legacy (passed the old check only, so warn) or :invalid
        def url_status(url)
          return :ok if url.nil? || url == ""
          return :invalid unless url.is_a?(String)
          return :ok if strict_url?(url)

          url.match?(URI::DEFAULT_PARSER.make_regexp) ? :legacy : :invalid
        end

        def strict_url?(url)
          uri = URI.parse(url)
          %w[http https].include?(uri.scheme&.downcase) && !uri.host.to_s.empty?
        rescue URI::Error
          false
        end

        def check_url(url, message)
          case url_status(url)
          when :invalid then @errors << message
          when :legacy then @warnings << "#{message} #{FUTURE_ERROR}"
          end
        end

        def validate_files
          @warnings << "This mod uses deprecated fields (fileType and fileURL)" if @data.key?(:fileType) || @data.key?(:fileURL)

          if !files.nil? && !files.is_a?(Hash)
            @errors << "Files must be an object"
            return
          end

          @warnings << "files should not be empty" if file_types.empty?

          file_types.each { |file_type| validate_filetype(file_type) }

          file_urls.each { |file_url| check_url(file_url, "Invalid URL: #{file_url}") }
        end

        def validate_filetype(file_type)
          name = file_type.to_s
          return if name.match?(filetype_pattern)

          if name.match?(legacy_filetype_pattern)
            @warnings << "Invalid fileType: #{name.upcase} #{FUTURE_ERROR}"
          else
            @errors << "Invalid fileType: #{name.upcase}"
          end
        end

        def validate_version
          if version.nil?
            @warnings << "Version was nil, it has been defaulted to 1.0"
          elsif !version.is_a?(String)
            @errors << "Version must be a string"
          else
            @warnings << "Version should be a version string" unless /\A\d+(\.\d+)*\z/.match?(version)
          end
        end

        def normalize_github_url(url)
          return url unless url.is_a?(String) && !url.empty?

          if url.match?(GITHUB_BLOB_RAW_URL_PATTERN)
            normalized = url.gsub(GITHUB_BLOB_RAW_URL_PATTERN, '\1://raw.githubusercontent.com/\2/\3/\4')
            @warnings << "GitHub URL converted to raw.githubusercontent.com format for direct download. Auto-fixed: #{url}"
            normalized
          else
            url
          end
        end

        def normalize_github_urls_in_data
          # Skip normalization if data is frozen (e.g., from Firestore)
          return if @data.frozen?

          @data[:imageURL] = normalize_github_url(@data[:imageURL])
          @data[:readmeURL] = normalize_github_url(@data[:readmeURL])
        end
      end
    end
  end
end
