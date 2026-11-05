# typed: strict
# frozen_string_literal: true

require "package_manager_cache"

RSpec.describe CoffeeBrewery::PackageManagerCache do
  describe "::path" do
    it "keeps every cache under COFFEEBREWER_CACHE" do
      expect(described_class.path("cargo_cache")).to eq(COFFEEBREWER_CACHE/"cargo_cache")
    end

    it "rejects unknown caches" do
      expect { described_class.path("foo_cache") }.to raise_error(ArgumentError)
    end
  end

  describe "::env" do
    it "points every package manager at a known cache" do
      known_paths = described_class.paths.map(&:to_s)
      cache_env = described_class.env.except(:_JAVA_OPTIONS, :BUNDLE_GLOBAL_GEM_CACHE)

      expect(cache_env.values - known_paths).to be_empty
    end
  end
end
