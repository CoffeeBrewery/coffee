# typed: strict
# frozen_string_literal: true

require "cmd/services"

RSpec.describe CoffeeBrewery::Cmd::Services::RestartSubcommand do
  describe "#run" do
    it "fails with empty list" do
      expect do
        described_class.new(CoffeeBrewery::Cmd::Services.new(%w[restart testball]).args,
                            targets: []).run
      end.to raise_error UsageError,
                         "Invalid usage: Formula(e) missing, please provide a formula name or use `--all`."
    end

    it "starts if services are not loaded" do
      expect(CoffeeBrewery::Services::Cli).not_to receive(:run)
      expect(CoffeeBrewery::Services::Cli).not_to receive(:stop)
      expect(CoffeeBrewery::Services::Cli).to receive(:start).once
      service = instance_double(CoffeeBrewery::Services::FormulaWrapper, service_name: "name", loaded?: false)
      expect do
        described_class.new(CoffeeBrewery::Cmd::Services.new(%w[restart testball]).args,
                            targets: [service]).run
      end.not_to raise_error
    end

    it "starts if services are loaded with file" do
      expect(CoffeeBrewery::Services::Cli).not_to receive(:run)
      expect(CoffeeBrewery::Services::Cli).to receive(:start).once
      expect(CoffeeBrewery::Services::Cli).to receive(:stop).once
      service = instance_double(CoffeeBrewery::Services::FormulaWrapper, service_name: "name", loaded?: true,
service_file_present?: true)
      expect do
        described_class.new(CoffeeBrewery::Cmd::Services.new(%w[restart testball]).args,
                            targets: [service]).run
      end.not_to raise_error
    end

    it "runs if services are loaded without file" do
      expect(CoffeeBrewery::Services::Cli).not_to receive(:start)
      expect(CoffeeBrewery::Services::Cli).to receive(:run).once
      expect(CoffeeBrewery::Services::Cli).to receive(:stop).once
      service = instance_double(CoffeeBrewery::Services::FormulaWrapper, service_name: "name", loaded?: true,
service_file_present?: false)
      expect do
        described_class.new(CoffeeBrewery::Cmd::Services.new(%w[restart testball]).args,
                            targets: [service]).run
      end.not_to raise_error
    end
  end
end
