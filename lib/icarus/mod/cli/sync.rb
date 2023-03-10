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

        no_commands do
          def firestore
            $firestore ||= Firestore.new
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
              puts "Dry run; no changes will be made"
              return
            end

            puts "Saving to Firestore..." if verbose?
            response = sync.update(info_array)
            puts response ? "Success" : "Failure (may be no changes)" if verbose?
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
              warn "Skipping List #{list.uniq_name} due to validation errors" && next unless list.valid?

              doc_id = sync.find(list)
              if doc_id
                puts "Found existing list #{list.name} at #{doc_id}" if verbose > 2
                list.id = doc_id
                verb = "Updating"
              end

              print format("#{verb} %-<name>60s", name: "'#{list.author || "NoOne"}/#{list.name || "Unnamed"}'") if verbose > 1

              if options[:dry_run]
                puts "Dry run; no changes will be made" if verbose > 1
                next
              end

              response = sync.update(list)
              puts format("%<status>10s", status: response ? "Success" : "Failure") if verbose > 1
            end

            if options[:dry_run]
              puts "Dry run; no changes will be made" if verbose?
              return
            end

            puts "Created/Updated #{info_array.count} Items" if verbose?

            delete_array = list_array.filter { |list| sync.find_info(list).nil? }

            return unless delete_array.any?

            puts "Deleting outdated items..." if verbose?
            delete_array.each do |list|
              print format("Deleting %-<name>60s", name: "'#{list.author || "NoOne"}/#{list.name || "Unnamed'"}") if verbose > 1
              response = sync.delete(list)
              puts format("%<status>10s", status: response ? "Success" : "Failure") if verbose > 1
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
