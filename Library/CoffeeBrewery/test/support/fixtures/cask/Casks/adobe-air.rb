# typed: false

cask "adobe-air" do
  version "1.2.3"
  sha256 "8c62a2b791cf5f0da6066a0a4b6e85f62949cd60975da062df44adf887f4370b"

  url "https://coffee.sh/TestCask-#{version}.dmg"
  name "Adobe AIR"
  desc "Cross-platform application runtime"
  homepage "https://coffee.sh/"

  app "TestCask.app"
end
