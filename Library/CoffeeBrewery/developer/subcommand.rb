# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "cli/parser"

Dir["#{__dir__}/subcommand/*.rb"].each do |subcommand|
  require "developer/subcommand/#{File.basename(subcommand, ".rb")}"
end

module CoffeeBrewery
  module Cmd
    class Developer < CoffeeBrewery::AbstractCommand
      class << self
        sig { params(args: T.untyped).void }
        def dispatch(args)
          subcommand_class = CoffeeBrewery::AbstractSubcommand
                             .subcommands_for(CoffeeBrewery::Cmd::Developer)
                             .find do |candidate|
            candidate.subcommand_name == args.subcommand
          end
          raise UsageError, "Unknown `coffee developer` subcommand: #{args.subcommand}" if subcommand_class.nil?

          subcommand_class.new(args).run
        end
      end
    end
  end
end
