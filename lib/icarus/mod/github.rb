# frozen_string_literal: true

require "octokit"

module Icarus
  module Mod
    # Helper methods for interacting with the Github API
    class Github
      attr_reader :client, :resources

      def initialize(repo = nil)
        self.repository = repo if repo
        @client = Octokit::Client.new(access_token: Config.github.token)
        @resources = []
      end

      def repository
        raise "You must specify a repository to use" unless @repository

        @repository
      end

      def repository=(repo)
        @resources = [] # reset the resources cache
        @repository = repo.gsub(%r{https?://.*github\.com/}, "")
      end

      # Recursively returns all resources in the repository
      #  path: the path to search in
      #  cache: whether to use the cached resources
      #  recursive: whether to recursively search subdirectories
      def all_files(path: nil, cache: true, recursive: false, &block)
        # If we've already been called for this repository, use the cached resources
        use_cache = @resources.any? && cache

        if use_cache
          @resources.each { |file| block.call(file) } if block
        else
          begin
            @client.contents(repository, path:).each do |entry|
              if entry[:type] == "dir"
                all_files(path: entry[:path], cache: false, recursive: true, &block) if recursive
                next # we don't need directories in our output
              end

              block&.call(entry)
              @resources << entry # cache the file
            end
          rescue Octokit::NotFound
            warn "WARNING: Could not access #{repository}: 404 - not found"
          end
        end

        @resources unless block
      end

      def find(pattern)
        all_files { |file| return file if /#{pattern}/i.match?(file[:name]) }
      end
    end
  end
end
