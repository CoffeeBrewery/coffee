# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/update-license-data"

RSpec.describe CoffeeBrewery::DevCmd::UpdateLicenseData do
  it_behaves_like "parseable arguments"
end
