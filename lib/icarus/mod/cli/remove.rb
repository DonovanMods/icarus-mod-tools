# frozen_string_literal: true

require "firestore"
require "cli/subcommand_base"

module Icarus
  module Mod
    module CLI
      # Remove CLI command definitions
      class Remove < SubcommandBase
        desc "repos REPO", "Removes an entry from 'meta/repos/list'"
        def repos(repo)
          firestore = Firestore.new
          repo_name = repo.gsub(%r{https?://.*github\.com/}, "")

          unless firestore.repositories.include?(repo_name)
            warn "Repository not found: #{repo_name}"
            exit 1
          end

          payload = firestore.repositories.reject { |r| r == repo_name }

          if firestore.update(:repositories, payload, merge: true)
            puts "Successfully removed repository: #{repo_name}"
          else
            puts "Failed to remove repository: #{repo_name}"
            exit 1
          end
        end
      end
    end
  end
end
