# typed: strict
# frozen_string_literal: true

require "cmd/cleanup"
require "cmd/shared_examples/args_parse"

RSpec.describe CoffeeBrewery::Cmd::CleanupCmd do
  before do
    FileUtils.mkdir_p COFFEEBREWER_LIBRARY/"CoffeeBrewery/vendor/"
    FileUtils.touch COFFEEBREWER_LIBRARY/"CoffeeBrewery/vendor/portable-ruby-version"
  end

  after do
    FileUtils.rm_rf COFFEEBREWER_LIBRARY/"CoffeeBrewery"
  end

  it_behaves_like "parseable arguments"

  describe "--prune=all", :cask, :integration_test do
    it "removes all files in CoffeeBrewery's cache" do
      setup_test_formula "testball"
      (COFFEEBREWER_CACHE/"test").write "test"

      expect { coffee "cleanup", "--prune=all" }
        .to output(%r{#{Regexp.escape(COFFEEBREWER_CACHE)}/test}o).to_stdout
        .and not_to_output.to_stderr
        .and be_a_success
      expect { coffee "cleanup", "--dry-run", "testball", cask_path("local-caffeine") }
        .to be_a_success
    end
  end
end
