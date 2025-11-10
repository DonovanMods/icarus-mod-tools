# frozen_string_literal: true

require "firestore"
require "cli/subcommand_base"

module Icarus
  module Mod
    module CLI
      # Remove CLI command definitions
      # rubocop:disable Style/GlobalVars
      class Remove < SubcommandBase
        class_option :dry_run, type: :boolean, default: false, desc: "Dry run (no changes will be made)"

        desc "repos REPO", "Removes an entry from 'meta/repos/list'"
        def repos(repo)
          repo_name = repo.gsub(%r{https?://.*github\.com/}, "")
          remove_item(
            :repositories,
            repo_name,
            "Repository",
            "Repository not found: #{repo_name}",
            "Successfully removed repository: #{repo_name}",
            "Failed to remove repository: #{repo_name}"
          )
        end

        desc "modinfo ITEM", "Removes an entry from 'meta/modinfo/list'"
        def modinfo(item)
          remove_item(
            :modinfo,
            item,
            "Modinfo entry",
            "Modinfo entry not found: #{item}",
            "Successfully removed modinfo entry: #{item}",
            "Failed to remove modinfo entry: #{item}"
          )
        end

        desc "toolinfo ITEM", "Removes an entry from 'meta/toolinfo/list'"
        def toolinfo(item)
          remove_item(
            :toolinfo,
            item,
            "Toolinfo entry",
            "Toolinfo entry not found: #{item}",
            "Successfully removed toolinfo entry: #{item}",
            "Failed to remove toolinfo entry: #{item}"
          )
        end

        private

        def remove_item(type, item, display_name, not_found_msg, success_msg, failure_msg)
          # Check existence
          collection = case type
                       when :repositories then firestore.repositories
                       when :modinfo     then firestore.modinfo
                       when :toolinfo    then firestore.toolinfo
                       else []
                       end
          unless collection.include?(item)
            warn not_found_msg
            exit 1
          end

          puts Paint["Removing #{display_name.downcase}: #{item}", :black] if verbose?

          if options[:dry_run]
            puts Paint["Dry run; no changes will be made", :yellow]
            return
          end

          if firestore.delete(type, item)
            puts Paint[success_msg, :green]
          else
            warn Paint[failure_msg, :red]
            exit 1
          end
        end

        def firestore
          $firestore ||= Firestore.new
        end
      end
      # rubocop:enable Style/GlobalVars
    end
  end
end
