# frozen_string_literal: true

require "github"
require "tools/modinfo"
require "tools/toolinfo"
require "tools/link_probe"
require "tools/entry_links"
require "tools/sync/helpers"

module Icarus
  module Mod
    module Tools
      # Read-only vetting of a GitHub repo before it is added to meta/repos: checks the repo itself, its
      # modinfo.json/toolinfo.json and every link they contain. Needs only the GitHub token, never Firestore.
      class RepoCheck
        include Sync::Helpers

        # Usage or GitHub API failure (as opposed to a repo that simply fails validation)
        class Error < StandardError; end

        TYPES = {
          modinfo: { file: "modinfo.json", type: "mod", key: :mods, entity: Modinfo },
          toolinfo: { file: "toolinfo.json", type: "tool", key: :tools, entity: Toolinfo }
        }.freeze

        # http: a callable (uri, verb) -> [status, location]; replaceable so specs need no network
        def initialize(repo, github: nil, http: nil)
          @github = github || Github.new
          @github.repository = repo
          @probe = LinkProbe.new(http:)
        end

        def call
          result = blank_result(repo_name)
          check_repo(result[:repo], result)
          result[:valid] = valid?(result)
          result
        rescue Octokit::Error => e
          raise Error, "GitHub API error: #{e.class.name.split("::").last}: #{e.message.lines.first&.strip}"
        end

        private

        def repo_name
          repo = @github.repository.to_s.delete_suffix("/").delete_suffix(".git")
          raise Error, "Repository must be given as OWNER/REPO" unless %r{\A[\w.-]+/[\w.-]+\z}.match?(repo)

          repo
        end

        def blank_result(repo)
          { repo:, exists: false, private: false, archived: false, default_branch: nil,
            info_files: { modinfo: nil, toolinfo: nil }, problems: [], entries: [], valid: false }
        end

        def check_repo(repo, result)
          record_repo(@github.client.repository(repo), result)
          check_info_files(result) unless result[:private] || result[:archived]
        rescue Octokit::NotFound
          result[:problems] << "repository not found"
        end

        def record_repo(data, result)
          result.merge!(exists: true, private: data[:private] ? true : false, archived: data[:archived] ? true : false,
                        default_branch: data[:default_branch])
          result[:problems] << "repository is private" if result[:private]
          result[:problems] << "repository is archived" if result[:archived]
        end

        def check_info_files(result)
          TYPES.each do |kind, meta|
            file = @github.find(meta[:file])
            next unless file

            result[:info_files][kind] = file[:download_url]
            check_info_file(meta, file[:download_url], result)
          end

          result[:problems] << "no modinfo.json or toolinfo.json found" if result[:info_files].values.none?
        end

        def check_info_file(meta, url, result)
          entries = entries_from(meta, retrieve_from_url(url))
          entries.each_with_index do |data, index|
            if usable_name?(data)
              result[:entries] << check_entry(meta, data)
            else
              result[:problems] << "#{meta[:file]}: entry #{index + 1} has no usable name (sync would skip it)"
            end
          end
        rescue Sync::RequestFailed, JSON::ParserError => e
          result[:problems] << "#{meta[:file]}: #{e.message}"
        end

        # Same rules as Sync::Entities#entries_from
        def entries_from(meta, body)
          entries = body[meta[:key]] if body.is_a?(Hash)
          raise JSON::ParserError, "no '#{meta[:key]}' array" unless entries.is_a?(Array)
          raise JSON::ParserError, "'#{meta[:key]}' entries must be objects" unless entries.all?(Hash)

          entries
        end

        def usable_name?(data)
          data[:name].is_a?(String) && /[a-z0-9]+/i.match?(data[:name])
        end

        def check_entry(meta, data)
          info = meta[:entity].new(data)
          entry = entry_for(meta[:type], info)

          entry[:warnings] << "tool ships a Windows executable" if meta[:type] == "tool" && EntryLinks.windows_tool?(info)
          EntryLinks.for(info).each { |field, url, download| check_link(entry, field, url, download) }
          entry
        end

        def entry_for(type, info)
          { type:, name: info.name, author: info.author, version: info.version,
            errors: info.errors.dup, warnings: info.warnings.dup, links: [] }
        end

        def check_link(entry, field, url, download)
          status, host, problem = @probe.call(url)
          entry[:links] << { field:, url:, status:, final_host: host }

          if problem || !LinkProbe::OK_STATUSES.include?(status)
            entry[download ? :errors : :warnings] << "#{field}: #{problem || "HTTP #{status}"} (#{url})"
          elsif download && !LinkProbe.github_host?(host)
            entry[:warnings] << "download hosted off GitHub: #{host}"
          end
        end

        def valid?(result)
          result[:exists] && result[:info_files].values.any? && result[:problems].empty? &&
            result[:entries].none? { |entry| entry[:errors].any? }
        end
      end
    end
  end
end
