# frozen_string_literal: true

require "octokit"

module Icarus
  module Mod
    # Helper methods for interacting with the Github API
    class Github
      attr_reader :client, :resources

      # owner/repo, optionally as a github.com URL (with .git, a trailing slash or a deeper path)
      REPO_PATTERN = %r{\A(?:(?:https?://)?(?:www\.)?github\.com/)?([A-Za-z0-9][\w.-]*)/([\w.-]+?)(?:\.git)?(?:[/?#].*)?\z}

      # The form meta/repos stores ("https://github.com/owner/repo"), or nil when +repo+ is not a GitHub repository
      def self.canonical_url(repo)
        match = REPO_PATTERN.match(repo.to_s.strip)
        match && "https://github.com/#{match[1]}/#{match[2]}"
      end

      def initialize(repo = nil)
        self.repository = repo if repo
        @client = Octokit::Client.new(access_token: Config.github.token)
        @resources = []
        @cache = {}
      end

      def repository
        raise "You must specify a repository to use" unless @repository

        @repository
      end

      def repository=(repo)
        @resources = [] # reset the resources cache
        @cache = {}
        @repository = repo.gsub(%r{https?://.*github\.com/}, "")
      end

      # Recursively returns all resources in the repository
      #  path: the path to search in
      #  cache: whether to use the cached resources
      #  recursive: whether to recursively search subdirectories
      # Results are cached per [path, recursive]; the top-level listing also lives in #resources
      def all_files(path: nil, cache: true, recursive: false, &block)
        key = [path, recursive]
        cached = key == [nil, false] ? @resources : @cache[key]

        # If we've already been called with these arguments for this repository, use the cached resources
        files = (cached if cache && cached&.any?) || fetch_files(path, recursive).tap do |found|
          key == [nil, false] ? @resources = found : @cache[key] = found
        end

        if block
          files.each { |file| block.call(file) }
          return nil
        end

        files
      end

      # Returns the first file whose name equals the given name (case-insensitive)
      def find(name)
        all_files { |file| return file if file[:name].to_s.casecmp?(name.to_s) }
      end

      private

      # Fetches the files (not directories) under path from the API
      def fetch_files(path, recursive)
        found = []

        @client.contents(repository, path:).each do |entry|
          if entry[:type] == "dir"
            found.concat(fetch_files(entry[:path], true)) if recursive
            next # we don't need directories in our output
          end

          found << entry
        end

        found
      rescue Octokit::NotFound
        warn "WARNING: Could not access #{repository}: 404 - not found"
        found
      end
    end
  end
end
