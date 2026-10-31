# frozen_string_literal: true

require "firestore"
require "tools/modinfo"

module Icarus
  module Mod
    module CLI
      # Sync CLI command definitions
      class Add < SubcommandBase
        class_option :dry_run, type: :boolean, default: false, desc: "Dry run (validate and show what would be added, but change nothing)"

        desc "modinfo", "Adds an entry to 'meta/modinfo/list'"
        def modinfo(item)
          add_to_list(:modinfo, :modinfo, item)
        end

        desc "toolinfo", "Adds an entry to 'meta/toolinfo/list'"
        def toolinfo(item)
          add_to_list(:toolinfo, :toolinfo, item)
        end

        desc "repos", "Adds an entry to 'meta/repos/list'"
        def repos(item)
          add_to_list(:repositories, :repositories, item)
        end

        desc "mod", "Adds an entry to 'mods'"
        method_option :modinfo, type: :string, required: true, default: "modinfo.json", desc: "Path to the modinfo.json file"
        def mod
          data = options[:modinfo]

          if data.nil? || !File.exist?(data)
            warn "Invalid data file: #{data}"
            exit 1
          end

          begin
            parsed = JSON.parse(File.read(data), symbolize_names: true)
          rescue JSON::ParserError => e
            warn "Invalid JSON in #{data}: #{e.message.lines.first.strip}"
            exit 1
          end

          mods = parsed[:mods] if parsed.is_a?(Hash)

          unless mods.is_a?(Array)
            warn "Invalid data file: no 'mods' list found in #{data}"
            exit 1
          end

          # Validate everything up front so a bad entry never leaves a partial add behind
          modinfos = mods.map { |mod| Icarus::Mod::Tools::Modinfo.new(mod.is_a?(Hash) ? mod : {}) }
          invalid = modinfos.reject(&:valid?)

          if invalid.any?
            invalid.each { |modinfo| warn "Invalid modinfo: #{modinfo.errors}" }
            exit 1
          end

          if options[:dry_run]
            modinfos.each { |modinfo| puts Paint["Would add: #{modinfo.name}", :yellow] }
            return
          end

          firestore = Firestore.new
          results = modinfos.map { |modinfo| report(firestore.update(:mod, modinfo, merge: true)) }

          exit 1 unless results.all?
        end

        no_commands do
          # Appends item to one of the meta lists, exiting 1 if the update fails
          def add_to_list(type, collection, item)
            if options[:dry_run]
              puts Paint["Would add to #{type}: #{item}", :yellow]
              return
            end

            firestore = Firestore.new
            payload = [firestore.send(collection), item].flatten.compact

            exit 1 unless report(firestore.update(type, payload, merge: true))
          end

          def report(success)
            puts success ? "Success" : "Failure"
            success
          end
        end
      end
    end
  end
end
