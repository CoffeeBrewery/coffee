# typed: true
# frozen_string_literal: true

require "test_bot"

RSpec.describe Homebrew::TestBot::Step do
  subject(:step) { described_class.new(command, env:, verbose:) }

  let(:command) { ["brew", "config"] }
  let(:env) { {} }
  let(:verbose) { false }

  describe "#run" do
    it "runs the command" do
      expect(step).to receive(:system_command)
        .with("brew", args: ["config"], env:, print_stderr: verbose, print_stdout: verbose)
        .and_return(instance_double(SystemCommand::Result, success?: true, merged_output: ""))
      step.run
    end
  end

  describe "#truncate_output" do
    it "keeps the context before a coloured error line" do
      output = "one\ntwo\n\e[31mError:\e[0m 1 problem detected.\n"
      expect(step.truncate_output(output, max_kb: 4, context_lines: 5)).to eq(output)
    end
  end
end
