# typed: strict
# frozen_string_literal: true

RSpec.describe "coffee custom-external-command", :integration_test, type: :system do
  it "is supported" do
    mktmpdir do |path|
      cmd = "custom-external-command-#{rand}"
      file = path/"coffee-#{cmd}"

      file.write <<~SH
        #!/bin/sh
        echo 'I am #{cmd}.'
      SH
      FileUtils.chmod "+x", file

      expect { coffee cmd, "PATH" => "#{path}#{File::PATH_SEPARATOR}#{ENV.fetch("PATH")}" }
        .to output("I am #{cmd}.\n").to_stdout
        .and not_to_output.to_stderr
        .and be_a_success
    end
  end
end
