# frozen_string_literal: true

require "tools/validator"
require "tools/repo_check"
require "tools/repo_report"

module Icarus
  module Mod
    module CLI
      # Sync CLI command definitions
      class Validate < SubcommandBase
        desc "modinfo", "Reads modinfo data from 'meta/modinfo/list' and Validates syntax of modfiles"
        def modinfo
          validate(:modinfo)
        end

        desc "toolinfo", "Reads Toolinfo data from 'meta/toolinfo/list' and Validates syntax of toolfiles"
        def toolinfo
          validate(:toolinfo)
        end

        desc "repo OWNER/REPO", "Vets a GitHub repo (and its modinfo/toolinfo links) before it is added to 'meta/repos/list'; read-only"
        method_option :json, type: :boolean, default: false, desc: "Print the result as JSON"
        long_desc <<~DESC
          Exits 0 when the repo is valid, 1 when it is not, and 2 on usage, config or GitHub API errors.
          Never writes to Firestore and does not need it; only the GitHub token from the config is used.
        DESC
        def repo(name)
          result = Icarus::Mod::Tools::RepoCheck.new(name).call

          if options[:json]
            puts JSON.generate(result)
          else
            Icarus::Mod::Tools::RepoReport.new(result, verbose:).print
          end
          exit(result[:valid] ? 0 : 1)
        rescue Icarus::Mod::Tools::RepoCheck::Error => e
          warn "Error: #{e.message}"
          exit 2
        end

        no_commands do
          def validate(type)
            exit_code = 0
            validator = Icarus::Mod::Tools::Validator.new(type)

            puts "Validating Entries..." if verbose?
            max_length = (validator.array.map { |info| info.uniq_name.length }.max || 0) + 1

            validator.array.each do |info|
              print Paint[format("%s %-#{max_length}s", "Running validation steps on", info.uniq_name), :cyan, :bright] if verbose > 1

              info.validate

              unless info.errors? || info.warnings?
                puts Paint["SUCCESS", :green, :bright] if verbose > 1
                next
              end

              if info.errors?
                exit_code = 1
                puts Paint["ERROR", :red, :bright] if verbose? && verbose > 1
                puts info.errors.map { |error| Paint["#{error} in #{info.uniq_name}", :red] }.join("\n")
                puts "\n" if verbose > 1
              end

              puts Paint["WARNING", :yellow, :bright] if info.warnings.any? && verbose > 1
              puts info.warnings.map { |warning| Paint["#{warning} in #{info.uniq_name}", :yellow] }.join("\n")
              puts "\n" if verbose > 1
            end
            exit exit_code
          end
        end
      end
    end
  end
end
