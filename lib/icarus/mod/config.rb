# frozen_string_literal: true

require "json"
require "ostruct"

module Icarus
  module Mod
    # Reads the configuration file
    class Config
      class << self
        def config
          return @config if @config

          read
        end

        def read(config_file = self.config_file)
          @config = JSON.parse(File.read(config_file), object_class: OpenStruct)
        end

        def firebase
          @config.firebase
        end

        def github
          @config.github
        end

        private

        def config_file
          @config_file ||= File.join(Dir.home, "/.imtconfig.json")
        end
      end
    end
  end
end
