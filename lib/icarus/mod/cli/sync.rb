# frozen_string_literal: true

require "tools/sync/modinfo_list"
require "tools/sync/toolinfo_list"
require "tools/sync/mods"
require "tools/sync/tools"

module Icarus
  module Mod
    module CLI
      # Sync CLI command definitions
      # rubocop:disable Style/GlobalVars
      class Sync < SubcommandBase
        $firestore = nil

        # Stage 2 refuses to delete more than this share of a collection (or to empty it) without --force
        MASS_DELETE_RATIO = 0.25
        MASS_DELETE_MIN = 5

        class_option :dry_run, type: :boolean, default: false, desc: "Dry run (no changes will be made)"
        class_option :force, type: :boolean, default: false,
                             desc: "Let mods/tools sync delete over #{(MASS_DELETE_RATIO * 100).to_i}% of a collection"

        desc "all", "Run all sync jobs"
        def all
          # Each stage exits 1 on failure; run the rest anyway, then exit 1 if any failed
          failed = %i[toolinfo tools modinfo mods].map do |stage|
            puts "Running #{stage.to_s.capitalize} Sync..." if verbose?
            invoke stage
            false
          rescue SystemExit => e
            !e.success?
          end

          exit 1 if failed.any?
        end

        desc "modinfo", "Reads from 'meta/repos/list' and Syncs any modinfo files we find (github only for now)"
        def modinfo
          sync_info(:modinfo)
        end

        desc "toolinfo", "Reads from 'meta/repos/list' and Syncs any toolinfo files we find (github only for now)"
        def toolinfo
          sync_info(:toolinfo)
        end

        desc "mods", "Reads from 'meta/modinfo/list' and updates the 'mods' database accordingly"
        method_option :check, type: :boolean, default: false, desc: "Validate modinfo without applying changes"
        def mods
          sync_list(:mods)
        end

        desc "tools", "Reads from 'meta/toolinfo/list' and updates the 'tools' database accordingly"
        method_option :check, type: :boolean, default: false, desc: "Validate toolinfo without applying changes"
        def tools
          sync_list(:tools)
        end

        desc "cleanup", "Remove duplicate entries from mods and tools collections"
        def cleanup
          cleanup_duplicates(:mods)
          cleanup_duplicates(:tools)
        end

        no_commands do
          def firestore
            $firestore ||= Firestore.new
          end

          def cleanup_duplicates(type)
            singular_type = type.to_s.chomp("s").to_sym
            collection = firestore.send(type)

            puts "Scanning #{type} for duplicates..." if verbose?

            # Group by [name, author]
            grouped = collection.group_by { |item| [item.name, item.author] }
            duplicates = grouped.select { |_, items| items.length > 1 }

            if duplicates.empty?
              puts "No duplicate #{type} found." if verbose?
              return
            end

            puts "Found #{duplicates.length} duplicate #{singular_type}(s) to clean up:" if verbose?

            deleted_count = 0
            duplicates.each do |key, items|
              name, author = key
              puts "  #{author}/#{name}: #{items.length} entries" if verbose?
              deleted_count += merge_duplicates(singular_type, items)
            end

            if options[:dry_run]
              puts Paint["Dry run; no changes made. Would have deleted #{deleted_count} duplicate #{type}.", :yellow] if verbose?
            elsif verbose?
              puts "Deleted #{deleted_count} duplicate #{type}."
            end
          end

          # Keeps the oldest entry (the ID clients already hold), copies the most recently updated entry's
          # data onto it, then deletes the rest. Returns how many entries were (or would be) deleted.
          def merge_duplicates(singular_type, items)
            keeper = items.min_by { |item| oldest_first_key(item) }
            newest = items.min_by { |item| newest_first_key(item) }
            to_delete = items.reject { |item| item.equal?(keeper) }

            puts "    Keeping: #{keeper.id} (created: #{keeper.created_at}, updated: #{keeper.updated_at})" if verbose?
            return 0 unless copy_onto_keeper(singular_type, keeper, newest)

            to_delete.each do |item|
              if options[:dry_run]
                puts Paint["    Would delete: #{item.id} (updated: #{item.updated_at})", :yellow] if verbose?
              else
                puts "    Deleting: #{item.id} (updated: #{item.updated_at})" if verbose?
                response = firestore.delete(singular_type, item)
                puts "      #{success_or_failure(response)}" if verbose > 1
              end
            end

            to_delete.length
          end

          def copy_onto_keeper(singular_type, keeper, newest)
            return true if newest.equal?(keeper)

            copying = "data from #{newest.id} (updated: #{newest.updated_at}) onto #{keeper.id}"
            if options[:dry_run]
              puts Paint["    Would copy #{copying}", :yellow] if verbose?
              return true
            end

            puts "    Copying #{copying}" if verbose?
            if firestore.replace_data(singular_type, id: keeper.id, data: newest.data)
              firestore.move_source(singular_type, from: newest.id, to: keeper.id)
              return true
            end

            warn Paint["    Failed to copy #{newest.id} onto #{keeper.id} for #{keeper.author}/#{keeper.name}; " \
                       "nothing deleted for this entry", :red]
            false
          end

          # Earliest created_at, then updated_at, then id: deterministic even with missing timestamps
          def oldest_first_key(item)
            time = item.created_at || item.updated_at
            [time ? time.to_r : Float::INFINITY, item.id.to_s]
          end

          # Latest updated_at, then created_at; ties go to the lowest id
          def newest_first_key(item)
            time = item.updated_at || item.created_at
            [time ? -time.to_r : Float::INFINITY, item.id.to_s]
          end

          # Drops from +delete_array+ every doc that may only be missing because its source could not be read
          # this run (#16): a doc mapped to a transiently failed URL, or, while any URL failed, a doc with no
          # recorded source yet. A source that is gone (404/410) is not a transient failure, so authors still
          # control removal, and docs from every other source are deleted as normal.
          def protect_transient_sources(sync, delete_array)
            failed_urls = sync.transient_failures
            return delete_array if failed_urls.empty?

            sources = sync.sources
            kept, deletable = delete_array.partition do |list|
              url = sources[list.id.to_s]
              url.nil? || failed_urls.include?(url)
            end
            warn_kept(failed_urls, kept, sources) if kept.any?

            deletable
          end

          def warn_kept(failed_urls, kept, sources)
            warn Paint["WARNING: #{failed_urls.count} source(s) could not be read this run:", :yellow, :bright]
            failed_urls.each { |url| warn Paint["  #{url}", :yellow] }
            warn Paint["WARNING: Kept #{kept.count} outdated item(s) instead of deleting them:", :yellow, :bright]
            kept.each do |list|
              url = sources[list.id.to_s]
              reason = url ? "its source could not be read (#{url})" : "no recorded source yet, and a source failed"
              warn Paint["  #{list.author || "NoOne"}/#{list.name || "Unnamed"} (#{list.id}): #{reason}", :yellow]
            end
          end

          def success_or_failure(status)
            format("%<status>10s", status: status ? Paint["Success", :green] : Paint["Failure", :red])
          end

          def sync_info(type)
            sync = (type == :modinfo ? Icarus::Mod::Tools::Sync::ModinfoList : Icarus::Mod::Tools::Sync::ToolinfoList).new(client: firestore)

            puts "Retrieving repository Data..." if verbose?
            repositories = sync.repositories

            raise Icarus::Mod::Tools::Error, "Unable to find any repositories!" unless repositories.any?

            puts "Retrieving Info Array..." if verbose?
            info_array = sync.data(repositories, verbose: verbose > 1)&.map(&:download_url)&.compact

            # The list update only ever adds URLs, so a repository we could not search keeps its entries (#16)
            sync.transient_failures.each do |repo|
              warn Paint["WARNING: Could not search #{repo} this run; its existing #{type} entries were kept", :yellow]
            end

            raise Icarus::Mod::Tools::Error, "no .json files found for #{type}" unless info_array&.any?

            if options[:dry_run]
              puts Paint["Dry run; no changes will be made", :yellow]
              return
            end

            puts Paint["Saving to Firestore...", :black] if verbose?
            response = sync.update(info_array)
            if verbose?
              puts response ? Paint["Success", :green, :bright] : Paint["Failure (may be no changes)", :red, :bright]
            end
          rescue Icarus::Mod::Tools::Error => e
            warn e.message
            exit 1
          end

          def sync_list(type)
            sync = (type == :mods ? Icarus::Mod::Tools::Sync::Mods : Icarus::Mod::Tools::Sync::Tools).new(client: firestore)

            puts "Syncing #{type} to #{Config.firebase.collections.send(type)}" if verbose > 1

            puts "Retrieving Info Data..." if verbose?
            info_array = sync.info_array

            puts "Retrieving List Data..." if verbose?
            # A snapshot: creating a doc appends it to the cached collection, which would dilute the delete guard
            list_array = sync.send(type).dup

            return if options[:check]

            updating = !options[:dry_run]
            puts "Updating List Data..." if verbose?
            info_array.each do |list|
              verb = "Creating"

              puts "Validating Info Data for #{list.uniq_name}..." if verbose > 2
              unless list.valid?
                warn Paint["Skipping List #{list.uniq_name} due to validation errors", :yellow, :bright]
                warn list.errors.map { |error| Paint[error, :red] }.join("\n") if verbose > 1

                next
              end

              doc_id = sync.find(list)
              if doc_id
                puts Paint["Found existing list #{list.name} at #{doc_id}", :black] if verbose > 2
                list.id = doc_id
                verb = "Updating"
              end

              if verbose > 1
                print format("#{verb} %-<name>60s",
                             name: "'#{list.author || "NoOne"}/#{list.name || "Unnamed"}'")
              end

              if options[:dry_run]
                puts Paint["Dry run; no changes will be made", :yellow] if verbose > 1
                next
              end

              response = sync.update(list)
              puts success_or_failure(response) if verbose > 1
            end

            unless options[:dry_run]
              puts "Created/Updated #{info_array.count} Items" if verbose?
              sync.save_sources
            end

            delete_array = protect_transient_sources(sync, list_array.filter { |list| sync.find_info(list).nil? })

            if options[:dry_run]
              preview_deletions(type, delete_array, list_array, info_array)
              puts Paint["Dry run; no changes will be made", :white] if verbose?
              return
            end

            return unless delete_array.any?

            raise Icarus::Mod::Tools::Error, mass_delete_message("Refusing", type, delete_array, list_array) if
              mass_delete?(delete_array, list_array, info_array)

            puts "Deleting outdated items..." if verbose?
            delete_array.each do |list|
              print "Deleting '#{list.author || "NoOne"}/#{list.name || "Unnamed"}'#{" " * 20}" if verbose > 1
              response = sync.delete(list)
              puts success_or_failure(response) if verbose > 1
            end

            puts "Deleted #{delete_array.count} outdated items" if verbose?
          rescue Icarus::Mod::Tools::Error => e
            warn e.message
            exit 1
          rescue StandardError
            # Keep the sources of the docs written before a failure, so the next run can protect them (#16)
            sync&.save_sources if updating
            raise
          end

          # A wave of 404s (a GitHub outage, a mass rename) looks like every author removing their file, so stage 2
          # will not delete more than MASS_DELETE_RATIO of a collection, or empty it, unless run with --force
          def mass_delete?(delete_array, list_array, info_array)
            return false if options[:force] || delete_array.empty?

            emptying = info_array.empty? && delete_array.size >= list_array.size
            too_many = delete_array.size >= MASS_DELETE_MIN && delete_array.size > list_array.size * MASS_DELETE_RATIO
            emptying || too_many
          end

          def mass_delete_message(verb, type, delete_array, list_array)
            Paint["#{verb} to delete #{delete_array.size} of #{list_array.size} #{type}; " \
                  "check the sources, then rerun with --force if this is intended", :red, :bright]
          end

          # What a real run would delete, and whether the mass-delete brake would stop it
          def preview_deletions(type, delete_array, list_array, info_array)
            return unless verbose?

            puts "Would delete #{delete_array.count} outdated item(s)#{":" if delete_array.any?}"
            delete_array.each { |list| puts Paint["  #{list.author || "NoOne"}/#{list.name || "Unnamed"} (#{list.id})", :yellow] }
            return unless mass_delete?(delete_array, list_array, info_array)

            warn mass_delete_message("Would refuse", type, delete_array, list_array)
          end
        end
      end
      # rubocop:enable Style/GlobalVars
    end
  end
end
