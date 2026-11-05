# typed: true
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/release"

RSpec.describe CoffeeBrewery::DevCmd::Release do
  it_behaves_like "parseable arguments"

  describe "#run" do
    before do
      allow(SystemCommand).to receive(:safe_system)
    end

    test_each(["--major", "--minor", nil].product([true, false])) do |version_flag, has_sponsors|
      it "reads release sponsors #{has_sponsors} from origin/main for #{version_flag.inspect} blog notes" do
        readme = mktmpdir/"README.md"
        stub_const("COFFEEBREWER_REPOSITORY", readme.dirname)
        readme.write <<~'MARKDOWN'
          [![Infrastructure](https://example.com/infrastructure.png)](https://example.com)
          CoffeeBrewery is generously supported by Named Sponsor and many others.
          <!-- release-sponsors -->
          [![Top One](https://example.com/one.png)](https://example.com/one)
          [![Top \[Two\] \\](https://example.com/two.png)](https://example.com/two)
          <!-- /release-sponsors -->
        MARKDOWN
        readme.write readme.read.gsub(/^\[!\[Top.*\n/, "") unless has_sponsors
        allow(Utils).to receive(:safe_popen_read).with(
          "git", "-C", COFFEEBREWER_REPOSITORY, "show", "origin/main:README.md"
        ).and_return(readme.read)
        readme.write <<~MARKDOWN
          <!-- release-sponsors -->
          [![Local Sponsor](https://example.com/local.png)](https://example.com/local)
          <!-- /release-sponsors -->
        MARKDOWN
        allow(CoffeeBrewery::EnvConfig).to receive(:no_auto_update?).and_return(false)
        allow(GitHub).to receive_messages(
          issues:                 [],
          get_latest_release:     { "tag_name" => "1.2.3" },
          get_release:            { "published_at" => "2020-01-01" },
          generate_release_notes: { "body" => "* A change by @contributor in https://example.com/pr" },
        )

        expected = <<~'MARKDOWN'
          - [A change](https://example.com/pr)

          Thanks to our top sponsors, Top One and Top \[Two\] \\, for supporting CoffeeBrewery.
        MARKDOWN
        if version_flag && has_sponsors
          expect { described_class.new([version_flag]).run }.to output(/#{Regexp.escape(expected)}/).to_stdout
        else
          expect do
            described_class.new([version_flag].compact).run
          end.not_to output(/Thanks to our top sponsors/).to_stdout
        end
      end
    end

    test_each([
      ["--major", false, [:fetch, :notes, :sponsors, :notes]],
      ["--minor", false, [:fetch, :notes, :sponsors, :notes]],
      [nil, false, [:notes]],
      [nil, true, [:fetch, :notes]],
    ]) do |version_flag, no_auto_update, expected_events|
      it "refreshes origin before notes for #{version_flag.inspect} with no auto-update #{no_auto_update}" do
        events = []
        command = described_class.new([version_flag].compact)
        allow(command).to receive_messages(puts: nil, opoo: nil, ohai: nil)
        allow(CoffeeBrewery::EnvConfig).to receive(:no_auto_update?).and_return(no_auto_update)
        allow(SystemCommand).to receive(:safe_system).with(
          "git", "-C", COFFEEBREWER_REPOSITORY, "fetch", "origin"
        ) { events << :fetch }
        allow(GitHub).to receive_messages(
          issues:             [],
          get_latest_release: { "tag_name" => "1.2.3" },
          get_release:        { "published_at" => "2020-01-01" },
        )
        allow(GitHub).to receive(:generate_release_notes) do
          events << :notes
          { "body" => "Release notes" }
        end
        allow(Utils).to receive(:safe_popen_read).with(
          "git", "-C", COFFEEBREWER_REPOSITORY, "show", "origin/main:README.md"
        ) do
          events << :sponsors
          ""
        end

        command.run

        expect(events).to eq(expected_events)
      end
    end

    it "requires an up-to-date origin/main before triggering the release workflow" do
      command = described_class.new(["--force"])

      allow(CoffeeBrewery::EnvConfig).to receive(:no_auto_update?).and_return(false)
      allow(GitHub).to receive_messages(
        issues:                 [],
        get_latest_release:     { "tag_name" => "1.2.3" },
        generate_release_notes: { "body" => "Release notes" },
      )
      allow(Utils).to receive(:safe_popen_read).with(
        "git", "-C", COFFEEBREWER_REPOSITORY, "rev-parse", "origin/main"
      ).and_return("local-sha\n")
      allow(GitHub::API).to receive(:open_rest).with(
        "#{GitHub::API_URL}/repos/CoffeeBrewery/coffee/releases?per_page=#{GitHub::MAX_PER_PAGE}",
        request_method: :GET,
        scopes:         GitHub::CREATE_ISSUE_FORK_OR_PR_SCOPES,
      ).and_return([])
      expect(GitHub::API).to receive(:commit).with("CoffeeBrewery", "coffee").and_return({ "sha" => "upstream-sha" })
      expect(GitHub).not_to receive(:workflow_dispatch_event)

      expect { command.run }
        .to raise_error(SystemExit)
        .and output(/Run `coffee update` before `coffee release --force`\./).to_stderr
    end

    it "refuses to release when open release blockers exist" do
      command = described_class.new([])

      allow(CoffeeBrewery::EnvConfig).to receive(:no_auto_update?).and_return(false)
      allow(GitHub).to receive(:issues)
        .with(repo: "CoffeeBrewery/coffee", state: "open", labels: "release blocker")
        .and_return([{ "html_url" => "https://github.com/CoffeeBrewery/coffee/issues/12345" }])

      expect { command.run }
        .to raise_error(SystemExit)
        .and output(%r{issues/12345}).to_stderr
    end

    it "refuses to release when open major/minor release blockers exist for a major release" do
      command = described_class.new(["--major"])

      allow(CoffeeBrewery::EnvConfig).to receive(:no_auto_update?).and_return(false)
      allow(GitHub).to receive(:issues)
        .with(repo: "CoffeeBrewery/coffee", state: "open", labels: "release blocker")
        .and_return([])
      allow(GitHub).to receive(:issues)
        .with(repo: "CoffeeBrewery/coffee", state: "open", labels: "major/minor release blocker")
        .and_return([{ "html_url" => "https://github.com/CoffeeBrewery/coffee/pull/54321" }])

      expect { command.run }
        .to raise_error(SystemExit)
        .and output(%r{pull/54321}).to_stderr
    end
  end

  describe "release lookup helpers" do
    let(:command) { described_class.new([]) }
    let(:releases) do
      [
        {
          "id"         => 1,
          "name"       => "1.2.3",
          "created_at" => "2025-01-01T00:00:00Z",
          "html_url"   => "https://github.com/CoffeeBrewery/coffee/releases/tag/1.2.3",
        },
        {
          "id"         => 2,
          "name"       => "1.2.3",
          "created_at" => "2025-01-02T00:00:00Z",
          "html_url"   => "https://github.com/CoffeeBrewery/coffee/releases/tag/1.2.3-2",
        },
        {
          "id"         => 3,
          "name"       => "1.2.2",
          "created_at" => "2024-12-31T00:00:00Z",
          "html_url"   => "https://github.com/CoffeeBrewery/coffee/releases/tag/1.2.2",
        },
        {
          "id"         => 4,
          "name"       => nil,
          "tag_name"   => "1.2.3",
          "created_at" => "2025-01-03T00:00:00Z",
          "html_url"   => "https://github.com/CoffeeBrewery/coffee/releases/tag/1.2.3-3",
        },
      ]
    end

    before do
      allow(GitHub::API).to receive(:open_rest).and_return(releases)
    end

    it "filters releases by name or tag name" do
      matching = command.matching_releases("1.2.3")
      expect(matching.map { |release| release["id"] }).to eq([1, 2, 4])
    end

    it "selects the latest matching release by creation time" do
      latest = command.latest_matching_release("1.2.3")
      expect(latest["id"]).to eq(4)
    end
  end
end
