# typed: strict
# frozen_string_literal: true

RSpec.describe "coffee update-if-needed", type: :system do
  it_behaves_like "a documented command", "update-if-needed", shell: true
end
