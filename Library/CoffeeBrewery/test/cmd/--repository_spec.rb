# typed: strict
# frozen_string_literal: true

require "open3"

RSpec.describe "coffee --repository", type: :system do
  it_behaves_like "a documented command", "--repository", shell: true

  it "prints CoffeeBrewery and Tap repositories" do
    stdout, stderr, status = Open3.capture3(
      {
        "COFFEEBREWER_LIBRARY"    => ENV.fetch("COFFEEBREWER_LIBRARY"),
        "COFFEEBREWER_REPOSITORY" => ENV.fetch("COFFEEBREWER_REPOSITORY"),
      },
      "/bin/bash", "-c", <<~SH,
        source "$1"
        homebrew---repository
        homebrew---repository foo/bar foo/homebrew-bar
      SH
      "bash", (COFFEEBREWER_LIBRARY_PATH/"cmd/--repository.sh").to_s
    )

    expect(status).to be_success
    expect(stdout).to eq(<<~EOS)
      #{ENV.fetch("COFFEEBREWER_REPOSITORY")}
      #{ENV.fetch("COFFEEBREWER_LIBRARY")}/Taps/foo/homebrew-bar
      #{ENV.fetch("COFFEEBREWER_LIBRARY")}/Taps/foo/homebrew-bar
    EOS
    expect(stderr).to be_empty
  end
end
