# typed: strict
# frozen_string_literal: true

require "utils/browser"

require "abstract_command"

module CoffeeBrewery
  module Cmd
    class Docs < AbstractCommand
      cmd_args do
        description <<~EOS
          Open CoffeeBrewery's online documentation at <#{COFFEEBREWER_DOCS_WWW}> in a browser.
        EOS
      end

      sig { override.void }
      def run
        Utils::Browser.open COFFEEBREWER_DOCS_WWW
      end
    end
  end
end
