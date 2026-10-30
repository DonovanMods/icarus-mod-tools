# frozen_string_literal: true

require "firestore"
require "github"
require "tools/sync/helpers"

module Icarus
  module Mod
    module Tools
      module Sync
        # Sync methods
        class ModinfoList
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

          def update(modinfo_array)
            @firestore.update(:modinfo, modinfo_array)
          end

          def modinfo(url)
            retrieve_from_url(url)
          end

          def data(repositories, verbose: false)
            @transient_failures = []

            repositories.map do |repo|
              print "searching #{repo}..." if verbose

              case repo
              when /github/
                find_modinfo(repo, verbose:)
              else
                puts "Skipped...repository type not supported yet" if verbose
              end
            end.compact
          end

          private

          def find_modinfo(repo, verbose: false)
            @github.repository = repo
            modinfo_url = @github.find("modinfo.json")

            unless modinfo_url
              puts "Skipped...no modinfo.json" if verbose
              return
            end

            puts "Found!" if verbose
            modinfo_url
          rescue Octokit::NotFound
            puts "Skipped...repository not found" if verbose
            nil
          rescue Octokit::Error, Faraday::Error => e
            @transient_failures << repo
            warn "Skipped; could not search #{repo} (#{e.class}); its existing modinfo entries are kept"
            nil
          end
        end
      end
    end
  end
end
