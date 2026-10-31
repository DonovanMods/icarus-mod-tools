# frozen_string_literal: true

require "cli/base"

module Icarus
  module Mod
    module CLI
      # Base class for all subcommands
      class SubcommandBase < Base
        class_option :verbose,
                     aliases: "-v", type: :boolean, repeatable: true, default: [true],
                     desc: "Increase verbosity. May be repeated for even more verbosity."

        no_commands do
          def check_false
            options[:verbose] = [] if options[:verbose].include?(false)
          end

          def verbose
            check_false
            options[:verbose]&.count || 0
          end

          def verbose?
            check_false
            options[:verbose]&.count&.positive?
          end
        end

        # rubocop:disable Style/OptionalBooleanParameter
        def self.banner(command, _namespace = nil, _subcommand = false)
          "#{basename} #{subcommand_prefix} #{command.usage}"
        end
        # rubocop:enable Style/OptionalBooleanParameter

        def self.subcommand_prefix
          name.gsub(/.*::/, "").gsub(/^[A-Z]/) { |match| match[0].downcase }.gsub(/[A-Z]/) { |match| "-#{match[0].downcase}" }
        end
      end
    end
  end
end
