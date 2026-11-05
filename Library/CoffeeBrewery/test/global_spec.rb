# typed: strict
# frozen_string_literal: true

RSpec.describe CoffeeBrewery, :integration_test do
  it "does not require slow dependencies unnecessarily" do
    expect do
      coffee "verify-undefined",
           "COFFEEBREWER_SORBET_RECURSIVE" => nil,
           "COFFEEBREWER_SORBET_RUNTIME"   => nil
    end
      .to not_to_output.to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end
end
