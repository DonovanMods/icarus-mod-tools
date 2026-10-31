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
          # --no-verbose appends false; Thor freezes options, so derive the level instead of rewriting it
          def verbose
            flags = options[:verbose] || []
            flags.include?(false) ? 0 : flags.count
          end

          def verbose?
            verbose.positive?
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
