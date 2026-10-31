# frozen_string_literal: true

require "digest"
require "set"
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

      # Internal map of mod/tool doc ID => the modinfo/toolinfo URL it was last synced from, kept in
      # meta/mod_sources and meta/tool_sources ({ sources: { "<doc id>" => "<url>" } }). Sync uses it to protect
      # only the docs of a source that failed transiently (#16). Consumers never read it; mods/tools docs are unchanged.
      def sources(type)
        key = pluralize(type)
        @sources ||= {}
        @sources[key] ||= begin
          data = @client.doc(sources_path(key)).get&.data
          (data&.dig(:sources) || {}).transform_keys(&:to_s)
        end
      end

      # Records (in memory) that doc +id+ came from +url+; #save_sources writes it
      def record_source(type, id, url)
        return if id.nil? || url.nil?

        map = sources(type)
        return if map[id.to_s] == url

        map[id.to_s] = url
        sources_changed(type) << id.to_s
      end

      # Writes the entries changed since the map was read or last saved. Only those keys are written (merged),
      # so entries another sync host recorded meanwhile are kept.
      def save_sources(type)
        changed = sources_changed(type)
        return true if changed.empty?

        map = sources(type)
        entries = changed.to_h { |id| [id, map.fetch(id) { Google::Cloud::Firestore::FieldValue.delete }] }
        response = @client.doc(sources_path(pluralize(type))).set({ sources: entries }, merge: true)
        success = response.is_a?(Google::Cloud::Firestore::CommitResponse::WriteResult)
        changed.clear if success

        success
      end

      # Gives doc +to+ the source of doc +from+ (cleanup copies +from+'s data onto +to+), and saves
      def move_source(type, from:, to:)
        url = sources(type)[from.to_s]
        return true unless url

        record_source(type, to, url)
        save_sources(type)
      end

      def find_by_type(type:, name:, author:)
        instance_variable_get(:"@#{type}").find { |obj| obj.name == name && obj.author == author }
      end

      # A deterministic document id for a new :mods or :tools document, so a mod that is deleted and later
      # re-added gets the same id back (#16). Author and name are case- and whitespace-normalised, and the
      # collection is part of the key so a mod and a tool with the same author and name do not collide.
      def stable_id(type, author:, name:)
        key = [pluralize(type), author.to_s.strip.downcase, name.to_s.strip.downcase].join("\0")
        Digest::SHA256.hexdigest(key)[0, 20]
      end

      def update(type, payload, merge: false)
        raise "You must specify a payload to update" if payload&.empty? || payload.nil?

        response = case type.to_sym
                   when :modinfo, :toolinfo, :repositories
                     update_list(type, [payload].flatten.uniq)
                   when :mod, :tool
                     create_or_update(pluralize(type), payload, merge:)
                   else
                     raise "Invalid type: #{type}"
                   end

        response.is_a?(Google::Cloud::Firestore::DocumentReference) || response.is_a?(Google::Cloud::Firestore::CommitResponse::WriteResult)
      end

      # Overwrites the :mod or :tool document at +id+ with +data+ (merge: false), keeping the document's id.
      # Used by `imt sync cleanup` to copy the newest duplicate's data onto the oldest one (#16).
      def replace_data(type, id:, data:)
        raise "Invalid type: #{type}" unless %i[mod tool].include?(type.to_sym)

        collection = pluralize(type)
        response = @client.doc("#{collections.send(collection)}/#{id}").set(data, merge: false)
        success = response.is_a?(Google::Cloud::Firestore::CommitResponse::WriteResult)
        replace_cached(collection, id, data) if success

        success
      end

      def delete(type, payload)
        case type.to_sym
        when :mod, :tool
          response = @client.doc("#{collections.send(pluralize(type))}/#{payload.id}").delete
          # Invalidate cache to prevent stale data
          if response.is_a?(Google::Cloud::Firestore::CommitResponse::WriteResult)
            cache_var = type == :mod ? :@mods : :@tools
            cached_collection = instance_variable_get(cache_var)
            cached_collection&.delete_if { |item| item.id == payload.id }
            forget_source(type, payload.id)
          end
        when :modinfo, :toolinfo, :repositories
          # Removed on the server, so entries another host added meanwhile are kept
          values = [payload].flatten
          response = @client.doc(collections.meta.send(type)).set(
            { list: Google::Cloud::Firestore::FieldValue.array_delete(*values) }, merge: true
          )
          # Invalidate cache if Firestore update was successful
          instance_variable_set(:"@#{type}", send(type) - values) if response.is_a?(Google::Cloud::Firestore::CommitResponse::WriteResult)
        else
          raise "Invalid type: #{type}"
        end

        response.is_a?(Google::Cloud::Firestore::CommitResponse::WriteResult)
      end

      private

      def list(type)
        case type.to_sym
        when :modinfo, :toolinfo, :repositories
          snapshot = @client.doc(collections.meta.send(type)).get
          snapshot.missing? ? [] : snapshot[:list] || []
        when :mods, :tools
          @client.col(collections.send(type)).get.map do |doc|
            klass = type == :mods ? Icarus::Mod::Tools::Modinfo : Icarus::Mod::Tools::Toolinfo
            klass.new(doc.data, id: doc.document_id, created: doc.create_time, updated: doc.update_time)
          end
        else
          raise "Invalid type: #{type}"
        end
      end

      # Adds +values+ to a meta list. The union happens on the server, so two sync hosts (or a sync and `imt add`)
      # writing at once keep each other's additions. The cache is refreshed so a later stage of `sync all` sees them.
      def update_list(type, values)
        response = @client.doc(collections.meta.send(type)).set(
          { list: Google::Cloud::Firestore::FieldValue.array_union(*values) }, merge: true
        )
        instance_variable_set(:"@#{type}", (send(type) + values).uniq) if response.is_a?(Google::Cloud::Firestore::CommitResponse::WriteResult)

        response
      end

      def create_or_update(type, payload, merge:)
        doc_id = payload.id || find_by_type(type:, name: payload.name, author: payload.author)&.id

        return @client.doc("#{collections.send(type)}/#{doc_id}").set(payload.to_h, merge:) if doc_id

        # New document: write it at its stable id (set creates it, or updates a doc a previous re-add left there).
        # Only if that id is already held by a different mod (same author/name in another case) fall back to add.
        cached_collection = instance_variable_get(:"@#{type}")
        new_id = stable_id(type, author: payload.author, name: payload.name)
        if cached_collection&.any? { |item| item.id == new_id }
          response = @client.col(collections.send(type)).add(payload.to_h)
          new_id = response.document_id
        else
          response = @client.doc("#{collections.send(type)}/#{new_id}").set(payload.to_h, merge:)
        end

        # Update cache to prevent duplicate creation within the same sync run
        payload.id = new_id
        cached_collection&.push(payload)

        response
      end

      def forget_source(type, id)
        return unless sources(type).delete(id.to_s)

        sources_changed(type) << id.to_s
        save_sources(type)
      end

      # Doc IDs whose source entry changed (or was removed) since the map was read or last saved
      def sources_changed(type)
        @sources_changed ||= Hash.new { |hash, key| hash[key] = Set.new }
        @sources_changed[pluralize(type)]
      end

      def sources_path(collection)
        name = :"#{collection.chomp('s')}_sources"
        collections.meta&.send(name) || "meta/#{name}"
      end

      def replace_cached(collection, id, data)
        cached_collection = instance_variable_get(:"@#{collection}")
        index = cached_collection&.index { |item| item.id == id }
        return unless index

        old = cached_collection[index]
        cached_collection[index] = old.class.new(data, id:, created: old.created_at, updated: Time.now)
      end

      def pluralize(type)
        type.to_s.end_with?("s") ? type.to_s : "#{type}s"
      end
    end
  end
end
