require "firestore"

RSpec.describe Icarus::Mod::Firestore do
  context "when initialized" do
    subject { described_class.new }

    let(:client_double) { instance_double(Google::Cloud::Firestore::Client) }
    let(:collection_double) { instance_double(Google::Cloud::Firestore::CollectionReference) }
    let(:document_double) { instance_double(Google::Cloud::Firestore::DocumentReference) }

    before do
      allow(collection_double).to receive(:get).and_return([])
      allow(document_double).to receive(:get).and_return(Struct.new(:list))
      allow(client_double).to receive_messages(doc: document_double, col: collection_double)
      allow(Google::Cloud::Firestore).to receive(:new).and_return(client_double)
      allow(Icarus::Mod::Config).to receive(:firebase).and_return(
        OpenStruct.new(
          credentials: OpenStruct.new(to_h: {}),
          collections: OpenStruct.new(
            meta: OpenStruct.new(
              modinfo: "test-modinfo",
              toolinfo: "test-toolinfo",
              repositories: "test-repositories"
            ),
            mods: "test-mods"
          )
        )
      )
    end

    it { is_expected.to be_a(described_class) }
    it { is_expected.to respond_to(:client) }
    it { is_expected.to respond_to(:repositories) }
    it { is_expected.to respond_to(:modinfo) }
    it { is_expected.to respond_to(:toolinfo) }
    it { is_expected.to respond_to(:mods) }
    it { is_expected.to respond_to(:tools) }
  end
end
