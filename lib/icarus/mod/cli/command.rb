# frozen_string_literal: true

require "cli/base"
require "cli/subcommand_base"
require "cli/sync"
require "cli/list"
require "cli/add"
require "cli/remove"
require "cli/validate"

module Icarus
  module Mod
    module CLI
      # The main CLI Command class for Icarus Mod Tools
      class Command < Base
        def initialize(*args)
          super

          if options[:version]
            puts "IcarusModTool (imt) v#{Icarus::Mod::VERSION}"
            exit 0
          end

          unless File.exist?(options[:config])
            warn "Could not find or read Config from '#{options[:config]}' - please create it or specify a different path with -C"
            exit 1
          end

          Icarus::Mod::Config.read(options[:config])
        end

        desc "sync", "Syncs the databases"
        subcommand "sync", Sync

        desc "list", "Lists the databases"
        subcommand "list", List

        desc "add", "Adds entries to the databases"
        subcommand "add", Add

        desc "remove", "Removes entries from the databases"
        subcommand "remove", Remove

        desc "validate", "Validates various entries"
        subcommand "validate", Validate
      end
    end
  end
end
