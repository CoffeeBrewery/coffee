# typed: strict
# frozen_string_literal: true

RSpec.describe "coffee --version", type: :system do
  it "prints the CoffeeBrewery's version", :integration_test do
    expect { brew_sh "--version" }
      .to output(/^CoffeeBrewery #{Regexp.escape(COFFEEBREWER_VERSION)}\n/o).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end
end
