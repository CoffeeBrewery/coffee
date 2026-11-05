# typed: strict
# frozen_string_literal: true

require "services/subcommand/cleanup"
require "services/system"
require "services/cli"

RSpec.describe CoffeeBrewery::Cmd::Services::CleanupSubcommand do
  describe "#run" do
    it "root - prints on empty cleanup" do
      expect(CoffeeBrewery::Services::System).to receive(:root?).once.and_return(true)
      expect(CoffeeBrewery::Services::Cli).to receive(:kill_orphaned_services).once.and_return([])
      expect(CoffeeBrewery::Services::Cli).to receive(:remove_unused_service_files).once.and_return([])

      expect do
        described_class.new(CoffeeBrewery::CLI::Args.new).run
      end.to output("All root services OK, nothing cleaned...\n").to_stdout
    end

    it "user - prints on empty cleanup" do
      expect(CoffeeBrewery::Services::System).to receive(:root?).once.and_return(false)
      expect(CoffeeBrewery::Services::Cli).to receive(:kill_orphaned_services).once.and_return([])
      expect(CoffeeBrewery::Services::Cli).to receive(:remove_unused_service_files).once.and_return([])

      expect do
        described_class.new(CoffeeBrewery::CLI::Args.new).run
      end.to output("All user-space services OK, nothing cleaned...\n").to_stdout
    end

    it "prints nothing on cleanup" do
      expect(CoffeeBrewery::Services::System).not_to receive(:root?)
      expect(CoffeeBrewery::Services::Cli).to receive(:kill_orphaned_services).once.and_return(["a"])
      expect(CoffeeBrewery::Services::Cli).to receive(:remove_unused_service_files).once.and_return(["b"])

      expect do
        described_class.new(CoffeeBrewery::CLI::Args.new).run
      end.not_to output("All user-space services OK, nothing cleaned...\n").to_stdout
    end
  end
end
