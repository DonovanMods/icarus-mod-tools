require "icarus/mod/version"

RSpec.describe "Icarus::Mod::VERSION" do
  subject { Icarus::Mod::VERSION }

  it { is_expected.not_to be_nil }
  it { is_expected.to match(/^\d+[.\d+]*/) }
end
