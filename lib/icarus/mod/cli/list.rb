# frozen_string_literal: true

require "firestore"
require "tools/modinfo"

module Icarus
  module Mod
    module CLI
      # Sync CLI command definitions
      class List < SubcommandBase
        desc "modinfo", "Displays data from 'meta/modinfo/list'"
        def modinfo
          modinfo_array = Firestore.new.send(:modinfo)
          puts modinfo_array
          puts "Total: #{modinfo_array.count}" if verbose > 1
        end

        desc "toolinfo", "Displays data from 'meta/toolinfo/list'"
        def toolinfo
          toolinfo_array = Firestore.new.send(:toolinfo)
          puts toolinfo_array
          puts "Total: #{toolinfo_array.count}" if verbose > 1
        end

        desc "repos", "Displays data from 'meta/repos/list'"
        def repos
          repos = Firestore.new.send(:repositories)
          puts repos
          puts "Total: #{repos.count}" if verbose > 1
        end

        desc "mods", "Displays data from 'mods'"
        method_option :sort, type: :string, default: "name", desc: "Sort by field (name, author, etc.)"
        method_option :filter, type: :array, default: [], desc: "Filter by field (name, author, etc.)"
        def mods
          list_for_type(:mods)
        end

        desc "tools", "Displays data from 'tools'"
        method_option :sort, type: :string, default: "name", desc: "Sort by field (name, author, etc.)"
        method_option :filter, type: :array, default: [], desc: "Filter by field (name, author, etc.)"
        def tools
          list_for_type(:tools)
        end

        no_commands do
          def list_for_type(type)
            klass = type == :mods ? Icarus::Mod::Tools::Modinfo : Icarus::Mod::Tools::Toolinfo
            valid_keys = klass::HASHKEYS + [:updated_at]
            sort_field = options[:sort]&.to_sym
            filter = !options[:filter].empty?

            if filter
              filter_field = options[:filter].first&.to_sym
              filter_value = options[:filter].last&.to_s

              unless options[:filter].empty? || options[:filter]&.count == 2
                raise Icarus::Mod::Tools::Error,
                      "Invalid filter option #{options[:filter]}"
              end

              unless filter_field && valid_keys.include?(filter_field)
                raise Icarus::Mod::Tools::Error,
                      "Invalid filter field '#{filter_field}'"
              end
            end

            raise Icarus::Mod::Tools::Error, "Invalid sort field '#{sort_field}'" unless valid_keys.include?(sort_field)

            puts "Sorted by #{sort_field}" if sort_field && verbose > 2
            puts "Filtered by #{filter_field} = #{filter_value}" if filter_field && verbose > 2

            items = Firestore.new.send(type)

            # Filter by field
            # Case-insensitive substring match; the value is literal text, not a regex
            items.select! { |item| item.send(filter_field).to_s.downcase.include?(filter_value.to_s.downcase) } if filter_field

            if items.empty?
              puts "no entries found" if verbose?
              return
            end

            header_format = "%-<name>50s %-<author>20s %-<version>10s %-<updated_at>20s"
            header_format += " %-<id>20s %<description>s" if verbose > 1

            if verbose?
              puts format(
                header_format,
                name: "NAME",
                author: "AUTHOR",
                version: "VERSION",
                updated_at: "LAST UPDATED",
                id: "ID",
                description: "DESCRIPTION"
              )
            end

            # Sort by field, optionally subsorting by name
            sorted = if sort_field == :name
                       items.sort_by(&:name)
                     else
                       items.sort_by { |item| [item.send(sort_field).to_s, item.name.to_s] }
                     end
            sorted.each do |item|
              data_format = "%-<name>50s %-<author>20s v%-<version>10s%-<updated_at>20s"
              data_format += " %-<id>20s %<description>s" if verbose > 1

              puts format(data_format, item.to_h.merge(id: item.id, updated_at: item.updated_at&.strftime("%Y-%m-%d %H:%M:%S")))
            end

            puts "Total: #{items.count}" if verbose?
          rescue Icarus::Mod::Tools::Error => e
            warn e.message
            exit 1
          end
        end
      end
    end
  end
end
