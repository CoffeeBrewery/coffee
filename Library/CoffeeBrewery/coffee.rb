# typed: strict
# frozen_string_literal: true

phase_timings_output = ENV.delete("COFFEEBREWER_PHASE_TIMINGS")
if phase_timings_output
  phase_timings_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f
  phase_timings_command = ARGV.dup
end

# `COFFEEBREWER_STACKPROF` should be set via `coffee prof --stackprof`, not manually.
if ENV["COFFEEBREWER_STACKPROF"]
  require "rubygems"
  require "stackprof"
  StackProf.start(mode: :wall, raw: true)
end

raise "COFFEEBREWER_BREW_FILE was not exported! Please call bin/coffee directly!" unless ENV["COFFEEBREWER_BREW_FILE"]
if $PROGRAM_NAME != __FILE__ && !$PROGRAM_NAME.end_with?("/bin/ruby-prof")
  raise "#{__FILE__} must not be loaded via `require`."
end

std_trap = trap("INT") { exit! 130 } # no backtrace thanks

require_relative "global"
require "utils/output"
require "utils/ruby"

require "utils/phase_timings"
if phase_timings_output
  CoffeeBrewery::PhaseTimings.start!(
    output_path: phase_timings_output,
    started_at:  phase_timings_started_at,
    command:     phase_timings_command,
  )
end

begin
  trap("INT", std_trap) # restore default CTRL-C handler

  if ENV["CI"]
    $stdout.sync = true
    $stderr.sync = true
  end

  empty_argv = ARGV.empty?
  help_flag_list = %w[-h --help --usage -?]
  help_flag = !ENV["COFFEEBREWER_HELP"].nil?
  help_cmd_index = T.let(nil, T.nilable(Integer))
  cmd = T.let(nil, T.nilable(String))

  ARGV.each_with_index do |arg, i|
    break if help_flag && cmd

    if arg == "help" && !cmd
      # Command-style help: `help <cmd>` is fine, but `<cmd> help` is not.
      help_flag = true
      help_cmd_index = i
    elsif !cmd && help_flag_list.exclude?(arg)
      cmd = ARGV.delete_at(i)
    end
  end

  ARGV.delete_at(help_cmd_index) if help_cmd_index

  args = CoffeeBrewery::PhaseTimings.measure("cli_parse") do
    require "cli/parser"
    CoffeeBrewery::CLI::Parser.new(CoffeeBrewery::Cmd::Brew).parse(ARGV.dup.freeze, ignore_invalid_options: true)
  end
  Context.current = args.context

  path = PATH.new(ENV.fetch("PATH"))
  homebrew_path = PATH.new(ENV.fetch("COFFEEBREWER_PATH"))

  # Add shared wrappers.
  path.prepend(COFFEEBREWER_SHIMS_PATH/"shared")
  homebrew_path.prepend(COFFEEBREWER_SHIMS_PATH/"shared")

  ENV["PATH"] = path.to_s

  require "commands"

  internal_cmd = T.let(false, T::Boolean)
  external_ruby_v2_cmd = T.let(false, T::Boolean)
  external_ruby_cmd_path = T.let(nil, T.nilable(Pathname))
  external_cmd_path = T.let(nil, T.nilable(Pathname))

  # `valid_internal_cmd?` requires the command's file, so this covers the
  # command's entire `require` graph: usually the largest phase of all.
  CoffeeBrewery::PhaseTimings.measure("command_load") do
    if cmd
      cmd = Commands::COFFEEBREWER_INTERNAL_COMMAND_ALIASES.fetch(cmd, cmd)
      internal_cmd = Commands.valid_internal_cmd?(cmd) || Commands.valid_internal_dev_cmd?(cmd)

      unless internal_cmd
        # Add contributed commands to PATH before checking.
        homebrew_path.append(Commands.tap_cmd_directories)

        # External commands expect a normal PATH
        ENV["PATH"] = homebrew_path.to_s

        external_ruby_v2_cmd = !Commands.external_ruby_v2_cmd_path(cmd).nil?
        external_ruby_cmd_path = Commands.external_ruby_cmd_path(cmd) unless external_ruby_v2_cmd
        external_cmd_path = Commands.external_cmd_path(cmd) if !external_ruby_v2_cmd && external_ruby_cmd_path.nil?
      end
    end
  end

  # Usage instructions should be displayed if and only if one of:
  # - a help flag is passed AND a command is matched
  # - a help flag is passed AND there is no command specified
  # - no arguments are passed
  if empty_argv || help_flag
    require "help"
    # `CoffeeBrewery::Help.help` may defer to a self-documenting external command's own
    # `--help` (e.g. `coffee help <cmd>`). Pass `--help`, not the CoffeeBrewery help flag
    # that triggered this (`-h`, `--usage`, `-?`), which the command may not know.
    if external_cmd_path
      ARGV.reject! { |arg| help_flag_list.include?(arg) }
      ARGV.push("--help")
    end
    CoffeeBrewery::Help.help cmd, remaining_args: args.remaining, empty_argv:
    # `CoffeeBrewery::Help.help` never returns, except for unknown and deferred commands.
  end

  if !help_flag && (internal_cmd || external_ruby_v2_cmd || external_ruby_cmd_path || external_cmd_path)
    CoffeeBrewery::EnvConfig.check_deprecated_bash_variables
  end

  if cmd.nil?
    raise UsageError, "Unknown command: coffee #{ARGV.join(" ")}"
  elsif internal_cmd || external_ruby_v2_cmd
    cmd_class = CoffeeBrewery::AbstractCommand.command(cmd)
    if cmd_class&.include?(CoffeeBrewery::ShellCommand)
      exec (COFFEEBREWER_LIBRARY_PATH.parent.parent/"bin/coffee").to_s, cmd, *ARGV
    end
    CoffeeBrewery.running_command = cmd
    if cmd_class
      install_from_api = !CoffeeBrewery::EnvConfig.no_install_from_api?
      require "api" if install_from_api
      CoffeeBrewery::PhaseTimings.install! if phase_timings_output
      CoffeeBrewery::API.fetch_api_files! if install_from_api

      command_instance = CoffeeBrewery::PhaseTimings.measure("cli_parse") { cmd_class.new }

      require "utils/analytics"
      Utils::Analytics.report_command_run(command_instance)
      command_instance.run
    else
      Utils::Output.odie "Unknown command: coffee #{cmd}"
    end
  elsif external_ruby_cmd_path
    CoffeeBrewery.running_command = cmd
    Utils::Ruby.require?(external_ruby_cmd_path)
    exit CoffeeBrewery.failed? ? 1 : 0
  elsif external_cmd_path
    ENV["COFFEEBREWER_CACHE"] = COFFEEBREWER_CACHE.to_s
    ENV["COFFEEBREWER_LIBRARY_PATH"] = COFFEEBREWER_LIBRARY_PATH.to_s
    exec external_cmd_path.to_s, *ARGV
  else
    raise UsageError, "Unknown command: coffee #{cmd}#{Commands.suggestion_message(cmd)}"
  end
rescue UsageError => e
  require "help"
  CoffeeBrewery::Help.help cmd, remaining_args: args&.remaining || [], usage_error: e.message
rescue SystemExit => e
  Utils::Output.onoe "Kernel.exit" if args&.debug? && !e.success?
  if args&.debug? || ARGV.include?("--debug")
    require "utils/backtrace"
    $stderr.puts Utils::Backtrace.clean(e)
  end
  raise
rescue Interrupt
  $stderr.puts # seemingly a newline is typical
  exit 130
rescue BuildError => e
  Utils::Analytics.report_build_error(e)
  e.dump(verbose: args&.verbose? || false)

  if OS.not_tier_one_configuration?
    $stderr.puts <<~EOS
      This build failure was expected, as this is not a Tier 1 configuration:
        #{Formatter.url("https://docs.coffee.sh/Support-Tiers")}
      #{Formatter.bold("Do not report any issues to CoffeeBrewery/* repositories!")}
      Read the above document instead before opening any issues or PRs.
    EOS
  elsif (formula = e.formula) && (formula.head? || formula.deprecated? || formula.disabled?)
    reason = if formula.head?
      "was built from an unstable upstream --HEAD"
    elsif formula.deprecated?
      "is deprecated"
    elsif formula.disabled?
      "is disabled"
    end
    $stderr.puts <<~EOS
      #{formula.name}'s formula #{reason}.
      This build failure is expected behaviour.
    EOS
  end

  exit 1
rescue RuntimeError, SystemCallError => e
  raise if e.message.empty?

  Utils::Output.onoe e
  if args&.debug? || ARGV.include?("--debug")
    require "utils/backtrace"
    $stderr.puts Utils::Backtrace.clean(e)
  end

  exit 1
# Catch any other types of exceptions.
rescue Exception => e # rubocop:disable Lint/RescueException
  Utils::Output.onoe e

  method_deprecated_error = e.is_a?(MethodDeprecatedError)
  require "utils/backtrace"
  $stderr.puts Utils::Backtrace.clean(e) if args&.debug? || ARGV.include?("--debug") || !method_deprecated_error

  if OS.not_tier_one_configuration?
    $stderr.puts <<~EOS
      This error was expected, as this is not a Tier 1 configuration:
        #{Formatter.url("https://docs.coffee.sh/Support-Tiers")}
      #{Formatter.bold("Do not report any issues to CoffeeBrewery/* repositories!")}
      Read the above document instead before opening any issues or PRs.
    EOS
  elsif CoffeeBrewery::EnvConfig.no_auto_update? &&
        (fetch_head = COFFEEBREWER_REPOSITORY/".git/FETCH_HEAD") &&
        (!fetch_head.exist? || (fetch_head.mtime.to_date < Date.today))
    $stderr.puts "#{Tty.bold}You have disabled automatic updates and have not updated today.#{Tty.reset}"
    $stderr.puts "#{Tty.bold}Do not report this issue until you've run `coffee update` and tried again.#{Tty.reset}"
  elsif (issues_url = (method_deprecated_error && e.issues_url) || Utils::Backtrace.tap_error_url(e))
    $stderr.puts Utils::Output.issue_reporting_message(issues_url)
  elsif internal_cmd && !method_deprecated_error
    if OS.nix_managed_homebrew?
      $stderr.puts Utils::Output.issue_reporting_message(OS::ISSUES_URL)
    else
      $stderr.puts Utils::Output.issue_reporting_message(OS::ISSUES_URL, homebrew: true)
    end
  end

  exit 1
else
  exit 1 if CoffeeBrewery.failed?
ensure
  if ENV["COFFEEBREWER_STACKPROF"]
    StackProf.stop
    StackProf.results("prof/stackprof.dump")
  end
  CoffeeBrewery::PhaseTimings.write! if phase_timings_output
end
