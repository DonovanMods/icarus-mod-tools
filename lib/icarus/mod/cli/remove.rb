# frozen_string_literal: true

require "firestore"
require "cli/subcommand_base"

module Icarus
  module Mod
    module CLI
      # Remove CLI command definitions
      class Remove < SubcommandBase
        class_option :dry_run, type: :boolean, default: false, desc: "Dry run (no changes will be made)"

        desc "repos REPO", "Removes an entry from 'meta/repos/list'"
        def repos(repo)
          repo_name = repo.gsub(%r{https?://.*github\.com/}, "")

          unless firestore.repositories.include?(repo_name)
            warn "Repository not found: #{repo_name}"
            exit 1
          end

          puts Paint["Removing repository: #{repo_name}", :black] if verbose?

          if options[:dry_run]
            puts Paint["Dry run; no changes will be made", :yellow]
            return
          end

          if firestore.delete(:repositories, repo_name)
            puts Paint["Successfully removed repository: #{repo_name}", :green]
          else
            warn Paint["Failed to remove repository: #{repo_name}", :red]
            exit 1
          end
        end

        desc "modinfo ITEM", "Removes an entry from 'meta/modinfo/list'"
        def modinfo(item)
          unless firestore.modinfo.include?(item)
            warn "Modinfo entry not found: #{item}"
            exit 1
          end

          puts Paint["Removing modinfo entry: #{item}", :black] if verbose?

          if options[:dry_run]
            puts Paint["Dry run; no changes will be made", :yellow]
            return
          end

          if firestore.delete(:modinfo, item)
            puts Paint["Successfully removed modinfo entry: #{item}", :green]
          else
            warn Paint["Failed to remove modinfo entry: #{item}", :red]
            exit 1
          end
        end

        private

        def firestore
          $firestore ||= Firestore.new
        end
      end
    end
  end
end
