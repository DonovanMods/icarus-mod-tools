# frozen_string_literal: true

require "firestore"
require "cli/subcommand_base"
require "tools/sync/helpers"

module Icarus
  module Mod
    module CLI
      # Remove CLI command definitions
      # rubocop:disable Style/GlobalVars
      class Remove < SubcommandBase
        include Tools::Sync::Helpers
        class_option :dry_run, type: :boolean, default: false, desc: "Dry run (no changes will be made)"

        desc "repos REPO", "Removes an entry from 'meta/repos/list' and cascades to associated mods/tools"
        method_option :cascade, type: :boolean, default: true,
                                desc: "Also remove associated modinfo, toolinfo, mods, and tools entries"
        def repos(repo)
          repo_name = repo.gsub(%r{https?://.*github\.com/}, "")

          # Check if repository exists
          unless firestore.repositories.include?(repo_name)
            warn "Repository not found: #{repo_name}"
            exit 1
          end

          puts Paint["Removing repository: #{repo_name}", :black] if verbose?

          if options[:cascade]
            cascade_delete_repo(repo_name)
          else
            # Just remove from repositories list
            remove_item(
              :repositories,
              repo_name,
              "Repository",
              "Repository not found: #{repo_name}",
              "Successfully removed repository: #{repo_name}",
              "Failed to remove repository: #{repo_name}"
            )
          end
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

        desc "mod MOD_ID", "Removes a mod from the 'mods' collection"
        def mod(mod_id)
          remove_entity(
            :mod,
            mod_id,
            "Mod",
            "Mod not found with ID: #{mod_id}",
            "Successfully removed mod: #{mod_id}",
            "Failed to remove mod: #{mod_id}"
          )
        end

        desc "tool TOOL_ID", "Removes a tool from the 'tools' collection"
        def tool(tool_id)
          remove_entity(
            :tool,
            tool_id,
            "Tool",
            "Tool not found with ID: #{tool_id}",
            "Successfully removed tool: #{tool_id}",
            "Failed to remove tool: #{tool_id}"
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

        def remove_entity(type, entity_id, display_name, not_found_msg, success_msg, failure_msg)
          # Find the entity by ID
          collection = type == :mod ? firestore.mods : firestore.tools
          entity = collection.find { |e| e.id == entity_id }

          unless entity
            warn not_found_msg
            exit 1
          end

          puts Paint["Removing #{display_name.downcase}: #{entity.name} (ID: #{entity_id})", :black] if verbose?

          if options[:dry_run]
            puts Paint["Dry run; no changes will be made", :yellow]
            return
          end

          if firestore.delete(type, entity)
            puts Paint[success_msg, :green]
          else
            warn Paint[failure_msg, :red]
            exit 1
          end
        end

        def cascade_delete_repo(repo_name)
          @delete_failures = []

          # Find all modinfo URLs belonging to this repository
          # Match full "owner/repo" path component, not substring
          repo_pattern = %r{/#{Regexp.escape(repo_name)}(?=/|$)}
          modinfo_urls = firestore.modinfo.select { |url| url.match?(repo_pattern) }
          toolinfo_urls = firestore.toolinfo.select { |url| url.match?(repo_pattern) }

          puts Paint["Found #{modinfo_urls.size} modinfo entries and #{toolinfo_urls.size} toolinfo entries", :cyan] if verbose?

          if options[:dry_run]
            puts Paint["Dry run; no changes will be made", :yellow]
            preview = preview_cascade_deletions(repo_name, modinfo_urls, toolinfo_urls)
            display_cascade_preview(repo_name, preview)
            return
          end

          # Delete modinfo URLs and their associated mods
          modinfo_urls.each do |url|
            puts Paint["  Removing modinfo: #{url}", :black] if verbose?
            track_delete(:modinfo, url) { firestore.delete(:modinfo, url) }

            # Find and delete associated mods
            delete_entities_from_url(url, :mod)
          end

          # Delete toolinfo URLs and their associated tools
          toolinfo_urls.each do |url|
            puts Paint["  Removing toolinfo: #{url}", :black] if verbose?
            track_delete(:toolinfo, url) { firestore.delete(:toolinfo, url) }

            # Find and delete associated tools
            delete_entities_from_url(url, :tool)
          end

          # Report any failures
          report_delete_failures
          report_fetch_failures

          # Finally, remove the repository
          if firestore.delete(:repositories, repo_name)
            puts Paint["Successfully removed repository and all associated entries: #{repo_name}", :green]
          else
            warn Paint["Failed to remove repository: #{repo_name}", :red]
            exit 1
          end
        end

        def delete_entities_from_url(url, type)
          # Fetch the modinfo/toolinfo JSON
          begin
            data = retrieve_from_url(url)
            entities = data[type == :mod ? :mods : :tools] || []

            entities.each do |entity_data|
              # Find ALL matching entities in Firestore by name and author
              collection = type == :mod ? firestore.mods : firestore.tools
              matching_entities = collection.select do |e|
                e.name == entity_data[:name] && e.author == entity_data[:author]
              end

              next if matching_entities.empty?

              if matching_entities.size > 1 && verbose?
                warn Paint["  Note: Found #{matching_entities.size} entities matching '#{entity_data[:name]}' by #{entity_data[:author]}", :yellow]
              end

              matching_entities.each do |entity|
                puts Paint["    Removing #{type}: #{entity.name} (ID: #{entity.id})", :black] if verbose?
                track_delete(type, "#{entity.name} (#{entity.id})") { firestore.delete(type, entity) }
              end
            end
          rescue SocketError, IOError, SystemCallError, Timeout::Error, JSON::ParserError => e
            @failed_entity_fetches ||= []
            @failed_entity_fetches << { url: url, error: e.class.name, message: e.message }
            warn Paint["Warning: Could not fetch #{url} to remove entities: #{e.message}", :yellow]
          end
        end

        def preview_cascade_deletions(repo_name, modinfo_urls, toolinfo_urls)
          mods = []
          tools = []

          modinfo_urls.each do |url|
            entities = fetch_entities_from_url(url, :mod)
            mods.concat(entities) if entities
          end

          toolinfo_urls.each do |url|
            entities = fetch_entities_from_url(url, :tool)
            tools.concat(entities) if entities
          end

          {
            modinfo_urls: modinfo_urls,
            toolinfo_urls: toolinfo_urls,
            mods: mods,
            tools: tools
          }
        end

        def fetch_entities_from_url(url, type)
          data = retrieve_from_url(url)
          entity_data_list = data[type == :mod ? :mods : :tools] || []

          collection = type == :mod ? firestore.mods : firestore.tools
          entities = []

          entity_data_list.each do |entity_data|
            matching_entities = collection.select do |e|
              e.name == entity_data[:name] && e.author == entity_data[:author]
            end
            entities.concat(matching_entities)
          end

          entities
        rescue SocketError, IOError, SystemCallError, Timeout::Error, JSON::ParserError => e
          warn Paint["Warning: Could not fetch #{url}: #{e.message}", :yellow] if verbose?
          nil
        end

        def display_cascade_preview(repo_name, preview)
          puts "Would remove:"
          puts "  - Repository: #{repo_name}"

          if preview[:modinfo_urls].any?
            puts "  - Modinfo URLs: #{preview[:modinfo_urls].size}"
            preview[:modinfo_urls].each { |url| puts "    • #{url}" }
          end

          if preview[:mods].any?
            puts "  - Mods: #{preview[:mods].size}"
            preview[:mods].each { |mod| puts "    • #{mod.name} by #{mod.author} (ID: #{mod.id})" }
          end

          if preview[:toolinfo_urls].any?
            puts "  - Toolinfo URLs: #{preview[:toolinfo_urls].size}"
            preview[:toolinfo_urls].each { |url| puts "    • #{url}" }
          end

          if preview[:tools].any?
            puts "  - Tools: #{preview[:tools].size}"
            preview[:tools].each { |tool| puts "    • #{tool.name} by #{tool.author} (ID: #{tool.id})" }
          end
        end

        def track_delete(type, identifier)
          success = yield
          unless success
            @delete_failures ||= []
            @delete_failures << { type: type, identifier: identifier.to_s }
          end
          success
        end

        def report_delete_failures
          return unless @delete_failures&.any?

          warn Paint["\nWarning: #{@delete_failures.size} delete operation(s) failed:", :red]
          @delete_failures.each do |failure|
            warn Paint["  • #{failure[:type]}: #{failure[:identifier]}", :red]
          end
        end

        def report_fetch_failures
          return unless @failed_entity_fetches&.any?

          warn Paint["\nWarning: Failed to fetch #{@failed_entity_fetches.size} URL(s) - some entities may not have been deleted:", :yellow]
          @failed_entity_fetches.each do |failure|
            warn Paint["  • #{failure[:url]} (#{failure[:error]})", :yellow]
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
