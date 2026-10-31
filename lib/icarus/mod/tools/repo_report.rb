# frozen_string_literal: true

require "paint"

module Icarus
  module Mod
    module Tools
      # Human-readable output for a RepoCheck result, in the style of `imt validate modinfo`
      class RepoReport
        def initialize(result, verbose: 1)
          @result = result
          @verbose = verbose
        end

        def print
          print_header
          @result[:problems].each { |problem| puts Paint["#{problem} in #{@result[:repo]}", :red] }
          @result[:entries].each { |entry| print_entry(entry) }
          print_verdict if @verbose.positive?
        end

        private

        def print_header
          puts Paint["Validating #{@result[:repo]}", :cyan, :bright] if @verbose.positive?
          return unless @verbose > 1

          puts Paint["Default branch: #{@result[:default_branch]}", :cyan]
          @result[:info_files].each { |kind, url| puts "#{kind}: #{url || "not found"}" }
        end

        def print_verdict
          valid = @result[:valid]
          puts Paint[valid ? "VALID" : "NOT VALID", valid ? :green : :red, :bright]
        end

        def print_links(entry, name)
          puts Paint["Checked #{entry[:type]} #{name}", :cyan, :bright]
          entry[:links].each { |link| puts "  #{link[:field]}: #{link[:status] || "failed"} #{link[:final_host]}" }
        end

        def print_entry(entry)
          name = "#{entry[:author].to_s.strip}/#{entry[:name].to_s.strip}"
          print_links(entry, name) if @verbose > 1
          entry[:errors].each { |error| puts Paint["#{error} in #{name}", :red] }
          entry[:warnings].each { |warning| puts Paint["#{warning} in #{name}", :yellow] }
        end
      end
    end
  end
end
