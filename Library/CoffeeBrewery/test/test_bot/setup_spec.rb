# typed: true
# frozen_string_literal: true

require "dev-cmd/test-bot"

RSpec.describe CoffeeBrewery::TestBot::Setup do
  subject(:setup) { described_class.new }

  describe "#run!" do
    it "is successful" do
      expect(setup).to receive(:test)
        .exactly(3).times
        .and_return(instance_double(CoffeeBrewery::TestBot::Step, passed?: true))

      expect(setup.run!(args: instance_double(CoffeeBrewery::Cmd::TestBotCmd::Args)).passed?).to be(true)
    end

    it "only ignores a doctor failure when requested" do
      ignore_doctor_failures = []
      step = instance_double(CoffeeBrewery::TestBot::Step, passed?: true)
      allow(setup).to receive(:test) do |*arguments, **options|
        ignore_doctor_failures << options[:ignore_failures] if arguments == %w[coffee doctor]
        step
      end

      setup.run!(args: instance_double(CoffeeBrewery::Cmd::TestBotCmd::Args))
      ENV["COFFEEBREWER_TEST_BOT_IGNORE_DOCTOR_FAILURE"] = "1"
      setup.run!(args: instance_double(CoffeeBrewery::Cmd::TestBotCmd::Args))

      expect(ignore_doctor_failures).to eq [false, true]
    end
  end
end
