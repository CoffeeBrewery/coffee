# typed: strict
# frozen_string_literal: true

require "bump"

RSpec.describe CoffeeBrewery::Bump do
  describe "::redacted_url" do
    it "masks env-token credentials embedded in a push URL" do
      allow(GitHub::API).to receive(:credentials).and_return("ghp_secrettoken")
      expect(described_class.redacted_url(
               "https://x-access-token:ghp_secrettoken@github.com/CoffeeBrewery/homebrew-core",
             ))
        .to eq("https://x-access-token:******@github.com/CoffeeBrewery/homebrew-core")
    end

    it "leaves a credential-free URL unchanged" do
      allow(GitHub::API).to receive(:credentials).and_return(nil)
      expect(described_class.redacted_url("https://github.com/CoffeeBrewery/homebrew-core"))
        .to eq("https://github.com/CoffeeBrewery/homebrew-core")
    end
  end
end
