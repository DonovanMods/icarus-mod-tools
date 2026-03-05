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

        class_option :dry_run, type: :boolean, default: false, desc: "Dry run (no changes will be made)"

        desc "all", "Run all sync jobs"
        def all
          puts "Running Toolinfo Sync..." if verbose?
          invoke :toolinfo

          puts "Running Tools Sync..." if verbose?
          invoke :tools

          puts "Running Modinfo Sync..." if verbose?
          invoke :modinfo

          puts "Running Mods Sync..." if verbose?
          invoke :mods
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

            duplicates.each do |key, items|
              name, author = key
              # Sort by updated_at descending, keep the most recent
              sorted = items.sort_by { |item| item.updated_at || Time.at(0) }.reverse
              keeper = sorted.first
              to_delete = sorted[1..]

              puts "  #{author}/#{name}: #{items.length} entries" if verbose?
              puts "    Keeping: #{keeper.id} (updated: #{keeper.updated_at})" if verbose?

              to_delete.each do |item|
                if options[:dry_run]
                  puts Paint["    Would delete: #{item.id} (updated: #{item.updated_at})", :yellow] if verbose?
                else
                  puts "    Deleting: #{item.id} (updated: #{item.updated_at})" if verbose?
                  response = firestore.delete(singular_type, item)
                  puts "      #{success_or_failure(response)}" if verbose > 1
                end
              end
            end

            deleted_count = duplicates.values.sum { |items| items.length - 1 }
            if options[:dry_run]
              puts Paint["Dry run; no changes made. Would have deleted #{deleted_count} duplicate #{type}.", :yellow] if verbose?
            else
              puts "Deleted #{deleted_count} duplicate #{type}." if verbose?
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
          end

          def sync_list(type)
            sync = (type == :mods ? Icarus::Mod::Tools::Sync::Mods : Icarus::Mod::Tools::Sync::Tools).new(client: firestore)

            puts "Syncing #{type} to #{Config.firebase.collections.send(type)}" if verbose > 1

            puts "Retrieving Info Data..." if verbose?
            info_array = sync.info_array

            puts "Retrieving List Data..." if verbose?
            list_array = sync.send(type)

            return if options[:check]

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
                             name: "'#{list.author || 'NoOne'}/#{list.name || 'Unnamed'}'")
              end

              if options[:dry_run]
                puts Paint["Dry run; no changes will be made", :yellow] if verbose > 1
                next
              end

              response = sync.update(list)
              puts success_or_failure(status: response) if verbose > 1
            end

            if options[:dry_run]
              puts Paint["Dry run; no changes will be made", :white] if verbose?
              return
            end

            puts "Created/Updated #{info_array.count} Items" if verbose?

            delete_array = list_array.filter { |list| sync.find_info(list).nil? }

            return unless delete_array.any?

            puts "Deleting outdated items..." if verbose?
            delete_array.each do |list|
              print "Deleting '#{list.author || 'NoOne'}/#{list.name || 'Unnamed'}'#{' ' * 20}" if verbose > 1
              response = sync.delete(list)
              puts success_or_failure(status: response) if verbose > 1
            end

            puts "Deleted #{delete_array.count} outdated items" if verbose?
          rescue Icarus::Mod::Tools::Error => e
            warn e.message
          end
        end
      end
      # rubocop:enable Style/GlobalVars
    end
  end
end
