# frozen_string_literal: true

require "paint"
require "thor"
require "tools"
require "version"

module Icarus
  module Mod
    module CLI
      # The Base CLI class for Icarus Mod Tools. This is inherited by all subcommands.
      class Base < Thor
        class_option :config,
                     aliases: "-C", type: :string, default: File.join(Dir.home, "/.imtconfig.json"),
                     desc: "Path to the config file"

        class_option :version,
                     aliases: "-V", type: :boolean,
                     desc: "Print the version and exit"

        def self.exit_on_failure?
          true
        end
      end
    end
  end
end
