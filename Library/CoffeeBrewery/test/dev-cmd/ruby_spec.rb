# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/ruby"

RSpec.describe CoffeeBrewery::DevCmd::Ruby do
  it_behaves_like "parseable arguments"

  it "can execute Ruby code without Sorbet runtime", :integration_test do
    ruby = <<~RUBY
      class SorbetRuntimeTest
        extend T::Sig

        sig { void }
        def check; end
      end

      abort if T::Utils.signature_for_method(SorbetRuntimeTest.instance_method(:check))
      abort if ENV.key?("BUNDLER_VERSION")
    RUBY
    env = {
      "COFFEEBREWER_DEV_CMD_RUN"             => "1",
      "COFFEEBREWER_TESTS_NO_SORBET_RUNTIME" => "1",
      "COFFEEBREWER_SORBET_RUNTIME"          => "1",
      "COFFEEBREWER_SORBET_RECURSIVE"        => "1",
    }

    expect { brew_sh "ruby", "--", "-e", ruby, env }
      .to be_a_success
      .and not_to_output.to_stdout
      .and not_to_output.to_stderr
  end

  # Keep the richer expression path in-process as `coffee ruby` subprocesses are slow.
  it "passes CoffeeBrewery libraries and code to Ruby" do
    cmd = described_class.new(["-e", "puts 'testball'.f.path"])

    expect(cmd).to receive(:exec).with(
      *COFFEEBREWER_RUBY_EXEC_ARGS,
      "-I", $LOAD_PATH.join(File::PATH_SEPARATOR),
      "-rglobal", "-rbrew_irb_helpers",
      "-e puts 'testball'.f.path"
    )

    cmd.run
  end
end
