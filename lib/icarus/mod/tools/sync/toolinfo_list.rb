# frozen_string_literal: true

require "firestore"
require "github"
require "tools/sync/helpers"

module Icarus
  module Mod
    module Tools
      module Sync
        # Sync methods
        class ToolinfoList
          include Helpers

          def initialize(client: nil)
            @firestore = client || Firestore.new
            @github = Github.new
            @repositories = []
            @transient_failures = []
          end

          # Repositories whose GitHub lookup failed this run for a reason that may clear up (rate limit,
          # 5xx, network error). Their entries already in the list are kept: #update only ever adds (#16).
          attr_reader :transient_failures

          def repositories
            @firestore.repositories
          end

          def update(toolinfo_array)
            @firestore.update(:toolinfo, toolinfo_array)
          end

          def toolinfo(url)
            retrieve_from_url(url)
          end

          def data(repositories, verbose: false)
            @transient_failures = []

            repositories.map do |repo|
              print "searching #{repo}..." if verbose

              # A GitHub URL, or a bare owner/repo (how `imt add repos` stored entries before 3.2.1)
              if Github.canonical_url(repo)
                find_toolinfo(repo, verbose:)
              elsif verbose
                puts "Skipped...repository type not supported yet"
              end
            end.compact
          end

          private

          def find_toolinfo(repo, verbose: false)
            @github.repository = repo
            toolinfo_url = @github.find("toolinfo.json")

            unless toolinfo_url
              puts "Skipped...no toolinfo.json" if verbose
              return
            end

            puts "Found!" if verbose
            toolinfo_url
          rescue Octokit::NotFound
            puts "Skipped...repository not found" if verbose
            nil
          rescue Octokit::Error, Faraday::Error => e
            @transient_failures << repo
            warn "Skipped; could not search #{repo} (#{e.class}); its existing toolinfo entries are kept"
            nil
          end
        end
      end
    end
  end
end
