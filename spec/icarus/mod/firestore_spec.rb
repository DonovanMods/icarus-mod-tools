# frozen_string_literal: true

require "firestore"
require "ostruct"

RSpec.describe Icarus::Mod::Firestore do
  subject(:firestore) { described_class.new }

  let(:client_double) { instance_double(Google::Cloud::Firestore::Client) }
  let(:collection_double) { instance_double(Google::Cloud::Firestore::CollectionReference) }
  let(:document_double) { instance_double(Google::Cloud::Firestore::DocumentReference) }
  let(:write_result_double) { instance_double(Google::Cloud::Firestore::CommitResponse::WriteResult) }
  let(:document_ref_double) { instance_double(Google::Cloud::Firestore::DocumentReference) }

  let(:firebase_config) do
    OpenStruct.new(
      credentials: OpenStruct.new(to_h: {}),
      collections: OpenStruct.new(
        meta: OpenStruct.new(
          modinfo: "meta/modinfo",
          toolinfo: "meta/toolinfo",
          repositories: "meta/repos"
        ),
        mods: "mods",
        tools: "tools"
      )
    )
  end

  before do
    allow(collection_double).to receive(:get).and_return([])
    allow(collection_double).to receive(:add).and_return(document_ref_double)
    allow(document_double).to receive(:get).and_return(OpenStruct.new(list: []))
    allow(document_double).to receive(:set).and_return(write_result_double)
    allow(document_double).to receive(:delete).and_return(write_result_double)
    allow(client_double).to receive_messages(doc: document_double, col: collection_double)
    allow(Google::Cloud::Firestore).to receive(:new).and_return(client_double)
    allow(Icarus::Mod::Config).to receive(:firebase).and_return(firebase_config)
  end

  describe "#initialize" do
    it "creates a Firestore client" do
      firestore
      expect(Google::Cloud::Firestore).to have_received(:new).with(credentials: {})
    end

    it "loads collections from config" do
      expect(firestore.collections).to eq(firebase_config.collections)
    end
  end

  describe "#repositories" do
    let(:repos_list) { ["owner/repo1", "owner/repo2"] }

    before do
      allow(document_double).to receive(:get).and_return(OpenStruct.new(list: repos_list))
    end

    it "returns the list of repositories" do
      expect(firestore.repositories).to eq(repos_list)
    end

    it "caches the result" do
      firestore.repositories
      firestore.repositories
      expect(client_double).to have_received(:doc).with("meta/repos").once
    end
  end

  describe "#modinfo" do
    let(:modinfo_list) { ["https://example.com/modinfo1.json", "https://example.com/modinfo2.json"] }

    before do
      allow(document_double).to receive(:get).and_return(OpenStruct.new(list: modinfo_list))
    end

    it "returns the list of modinfo URLs" do
      expect(firestore.modinfo).to eq(modinfo_list)
    end
  end

  describe "#toolinfo" do
    let(:toolinfo_list) { ["https://example.com/toolinfo1.json"] }

    before do
      allow(document_double).to receive(:get).and_return(OpenStruct.new(list: toolinfo_list))
    end

    it "returns the list of toolinfo URLs" do
      expect(firestore.toolinfo).to eq(toolinfo_list)
    end
  end

  describe "#mods" do
    let(:doc_data) do
      {
        name: "Test Mod",
        author: "Test Author",
        version: "1.0",
        description: "A test mod"
      }
    end
    let(:doc_snapshot) do
      double("DocumentSnapshot",
        data: doc_data,
        document_id: "test-doc-id",
        create_time: Time.now,
        update_time: Time.now)
    end

    before do
      allow(collection_double).to receive(:get).and_return([doc_snapshot])
    end

    it "returns an array of Modinfo objects" do
      expect(firestore.mods).to all(be_a(Icarus::Mod::Tools::Modinfo))
    end

    it "sets the document ID on each Modinfo" do
      expect(firestore.mods.first.id).to eq("test-doc-id")
    end
  end

  describe "#tools" do
    let(:doc_data) do
      {
        name: "Test Tool",
        author: "Test Author",
        version: "1.0",
        description: "A test tool",
        fileType: "zip",
        fileURL: "https://example.com/tool.zip"
      }
    end
    let(:doc_snapshot) do
      double("DocumentSnapshot",
        data: doc_data,
        document_id: "test-tool-id",
        create_time: Time.now,
        update_time: Time.now)
    end

    before do
      allow(collection_double).to receive(:get).and_return([doc_snapshot])
    end

    it "returns an array of Toolinfo objects" do
      expect(firestore.tools).to all(be_a(Icarus::Mod::Tools::Toolinfo))
    end
  end

  describe "#find_by_type" do
    let(:modinfo) { Icarus::Mod::Tools::Modinfo.new({ name: "Test Mod", author: "Test Author", version: "1.0", description: "Test" }) }

    before do
      firestore.instance_variable_set(:@mods, [modinfo])
    end

    it "finds an item by type, name, and author" do
      result = firestore.find_by_type(type: "mods", name: "Test Mod", author: "Test Author")
      expect(result).to eq(modinfo)
    end

    it "returns nil if not found" do
      result = firestore.find_by_type(type: "mods", name: "Nonexistent", author: "Nobody")
      expect(result).to be_nil
    end
  end

  describe "#update" do
    context "with nil payload" do
      it "raises an error" do
        expect { firestore.update(:modinfo, nil) }.to raise_error(/must specify a payload/)
      end
    end

    context "with empty payload" do
      it "raises an error" do
        expect { firestore.update(:modinfo, []) }.to raise_error(/must specify a payload/)
      end
    end

    context "with :modinfo type" do
      let(:existing_modinfo) { ["https://existing.com/modinfo.json"] }
      let(:new_modinfo) { "https://new.com/modinfo.json" }

      before do
        allow(document_double).to receive(:get).and_return(OpenStruct.new(list: existing_modinfo))
        allow(write_result_double).to receive(:is_a?) do |klass|
          klass == Google::Cloud::Firestore::CommitResponse::WriteResult
        end
      end

      it "merges with existing modinfo and updates" do
        firestore.update(:modinfo, new_modinfo)
        expect(document_double).to have_received(:set).with({ list: [existing_modinfo.first, new_modinfo] }, merge: false)
      end

      it "returns true on success" do
        expect(firestore.update(:modinfo, new_modinfo)).to be true
      end
    end

    context "with :toolinfo type" do
      let(:new_toolinfo) { "https://new.com/toolinfo.json" }

      it "updates toolinfo list" do
        firestore.update(:toolinfo, new_toolinfo)
        expect(document_double).to have_received(:set).with({ list: [new_toolinfo] }, merge: false)
      end
    end

    context "with :repositories type" do
      let(:repos_payload) { ["owner/repo1", "owner/repo2"] }

      it "updates repositories list" do
        firestore.update(:repositories, repos_payload)
        expect(document_double).to have_received(:set).with({ list: repos_payload }, merge: false)
      end
    end

    context "with :mod type" do
      let(:modinfo) do
        Icarus::Mod::Tools::Modinfo.new({
          name: "Test Mod",
          author: "Test Author",
          version: "1.0",
          description: "Test"
        })
      end

      context "when mod does not exist" do
        before do
          firestore.instance_variable_set(:@mods, [])
        end

        it "creates a new document" do
          firestore.update(:mod, modinfo)
          expect(collection_double).to have_received(:add)
        end
      end

      context "when mod exists" do
        let(:existing_modinfo) do
          Icarus::Mod::Tools::Modinfo.new(
            { name: "Test Mod", author: "Test Author", version: "1.0", description: "Test" },
            id: "existing-id"
          )
        end

        before do
          firestore.instance_variable_set(:@mods, [existing_modinfo])
        end

        it "updates existing document" do
          modinfo_with_id = Icarus::Mod::Tools::Modinfo.new(
            { name: "Test Mod", author: "Test Author", version: "2.0", description: "Updated" },
            id: "existing-id"
          )
          firestore.update(:mod, modinfo_with_id)
          expect(document_double).to have_received(:set)
        end
      end
    end

    context "with :tool type" do
      let(:toolinfo) do
        Icarus::Mod::Tools::Toolinfo.new({
          name: "Test Tool",
          author: "Test Author",
          version: "1.0",
          description: "Test",
          fileType: "zip",
          fileURL: "https://example.com/tool.zip"
        })
      end

      before do
        firestore.instance_variable_set(:@tools, [])
      end

      it "creates a new tool document" do
        firestore.update(:tool, toolinfo)
        expect(collection_double).to have_received(:add)
      end
    end

    context "with invalid type" do
      it "raises an error" do
        expect { firestore.update(:invalid, "payload") }.to raise_error(/Invalid type/)
      end
    end

    context "with merge option" do
      let(:new_modinfo) { "https://new.com/modinfo.json" }

      it "passes merge option to set" do
        firestore.update(:modinfo, new_modinfo, merge: true)
        expect(document_double).to have_received(:set).with(hash_including(:list), merge: true)
      end
    end
  end

  describe "#delete" do
    context "with :mod type" do
      let(:modinfo) do
        instance_double(Icarus::Mod::Tools::Modinfo, id: "doc-to-delete")
      end

      before do
        allow(write_result_double).to receive(:is_a?).with(Google::Cloud::Firestore::CommitResponse::WriteResult).and_return(true)
      end

      it "deletes the document" do
        firestore.delete(:mod, modinfo)
        expect(document_double).to have_received(:delete)
      end

      it "returns true on success" do
        expect(firestore.delete(:mod, modinfo)).to be true
      end
    end

    context "with :tool type" do
      let(:toolinfo) do
        instance_double(Icarus::Mod::Tools::Toolinfo, id: "tool-to-delete")
      end

      it "deletes the document" do
        firestore.delete(:tool, toolinfo)
        expect(document_double).to have_received(:delete)
      end
    end

    context "with :modinfo type" do
      let(:modinfo_list) { ["https://keep.com/modinfo.json", "https://delete.com/modinfo.json"] }

      before do
        allow(document_double).to receive(:get).and_return(OpenStruct.new(list: modinfo_list))
        allow(write_result_double).to receive(:is_a?).with(Google::Cloud::Firestore::CommitResponse::WriteResult).and_return(true)
      end

      it "removes the item from the list" do
        firestore.delete(:modinfo, "https://delete.com/modinfo.json")
        expect(document_double).to have_received(:set).with({ list: ["https://keep.com/modinfo.json"] })
      end

      it "invalidates the cache" do
        # Populate the cache by calling modinfo
        firestore.modinfo

        # Update the stub to return the new list after deletion
        allow(document_double).to receive(:get).and_return(OpenStruct.new(list: ["https://keep.com/modinfo.json"]))

        # Delete an item, which should invalidate the cache
        firestore.delete(:modinfo, "https://delete.com/modinfo.json")

        # Verify that subsequent calls to modinfo return the updated list
        expect(firestore.modinfo).to eq(["https://keep.com/modinfo.json"])
      end
    end

    context "with :toolinfo type" do
      let(:toolinfo_list) { ["https://keep.com/toolinfo.json", "https://delete.com/toolinfo.json"] }

      before do
        allow(document_double).to receive(:get).and_return(OpenStruct.new(list: toolinfo_list))
      end

      it "removes the item from the list" do
        firestore.delete(:toolinfo, "https://delete.com/toolinfo.json")
        expect(document_double).to have_received(:set).with({ list: ["https://keep.com/toolinfo.json"] })
      end
    end

    context "with :repositories type" do
      let(:repos_list) { ["keep/repo", "delete/repo"] }

      before do
        allow(document_double).to receive(:get).and_return(OpenStruct.new(list: repos_list))
      end

      it "removes the repository from the list" do
        firestore.delete(:repositories, "delete/repo")
        expect(document_double).to have_received(:set).with({ list: ["keep/repo"] })
      end
    end

    context "with invalid type" do
      it "raises an error" do
        expect { firestore.delete(:invalid, "payload") }.to raise_error(/Invalid type/)
      end
    end
  end

  describe "private #pluralize" do
    it "adds s to singular types" do
      expect(firestore.send(:pluralize, :mod)).to eq("mods")
      expect(firestore.send(:pluralize, :tool)).to eq("tools")
    end

    it "does not double-pluralize" do
      expect(firestore.send(:pluralize, :mods)).to eq("mods")
      expect(firestore.send(:pluralize, :tools)).to eq("tools")
    end
  end

  describe "private #list" do
    context "with invalid type" do
      it "raises an error" do
        expect { firestore.send(:list, :invalid) }.to raise_error(/Invalid type/)
      end
    end
  end
end
