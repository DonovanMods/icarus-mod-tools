# frozen_string_literal: true

require "google/cloud/firestore"
require "tools/modinfo"
require "tools/toolinfo"

module Icarus
  module Mod
    # Helper methods for interacting with the Firestore API
    class Firestore
      attr_reader :client, :collections

      def initialize
        @client = Google::Cloud::Firestore.new(credentials: Config.firebase.credentials.to_h)
        @collections = Config.firebase.collections
        @repositories = repositories
        @modinfo = modinfo
        @toolinfo = toolinfo
        @mods = mods
        @tools = tools
      end

      def repositories
        @repositories ||= list(:repositories)
      end

      def modinfo
        @modinfo ||= list(:modinfo)
      end

      def toolinfo
        @toolinfo ||= list(:toolinfo)
      end

      def mods
        @mods ||= list(:mods)
      end

      def tools
        @tools ||= list(:tools)
      end

      def find_by_type(type:, name:, author:)
        instance_variable_get(:"@#{type}").find { |obj| obj.name == name && obj.author == author }
      end

      def update(type, payload, merge: false)
        raise "You must specify a payload to update" if payload&.empty? || payload.nil?

        response = case type.to_sym
                   when :modinfo, :toolinfo
                     update_array = (send(type) + [payload]).flatten.uniq
                     @client.doc(collections.meta.send(type)).set({ list: update_array }, merge:) if update_array.any?
                   when :repositories
                     @client.doc(collections.meta.repositories).set({ list: payload }, merge:)
                   when :mod, :tool
                     create_or_update(pluralize(type), payload, merge:)
                   else
                     raise "Invalid type: #{type}"
                   end

        response.is_a?(Google::Cloud::Firestore::DocumentReference) || response.is_a?(Google::Cloud::Firestore::CommitResponse::WriteResult)
      end

      def delete(type, payload)
        case type.to_sym
        when :mod, :tool
          response = @client.doc("#{collections.send(pluralize(type))}/#{payload.id}").delete
        when :modinfo, :toolinfo, :repositories
          update_array = (send(type) - [payload]).flatten.uniq
          return false if update_array.empty?

          response = @client.doc(collections.meta.send(type)).set({ list: update_array })
        else
          raise "Invalid type: #{type}"
        end

        response.is_a?(Google::Cloud::Firestore::CommitResponse::WriteResult)
      end

      private

      def list(type)
        case type.to_sym
        when :modinfo, :toolinfo, :repositories
          @client.doc(collections.meta.send(type)).get[:list]
        when :mods, :tools
          @client.col(collections.send(type)).get.map do |doc|
            klass = type == :mods ? Icarus::Mod::Tools::Modinfo : Icarus::Mod::Tools::Toolinfo
            klass.new(doc.data, id: doc.document_id, created: doc.create_time, updated: doc.update_time)
          end
        else
          raise "Invalid type: #{type}"
        end
      end

      def create_or_update(type, payload, merge:)
        doc_id = payload.id || find_by_type(type:, name: payload.name, author: payload.author)&.id

        return @client.doc("#{collections.send(type)}/#{doc_id}").set(payload.to_h, merge:) if doc_id

        @client.col(collections.send(type)).add(payload.to_h)
      end

      def pluralize(type)
        type.to_s.end_with?("s") ? type.to_s : "#{type}s"
      end
    end
  end
end
