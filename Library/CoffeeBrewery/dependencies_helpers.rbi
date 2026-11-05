# typed: strict

module DependenciesHelpers
  include Kernel

  # This sig is in an RBI to avoid both circular dependencies and unnecessary requires
  sig {
    params(args: T.any(CoffeeBrewery::Cmd::Deps::Args, CoffeeBrewery::Cmd::Uses::Args))
      .returns([T::Array[Symbol], T::Array[Symbol]])
  }
  def args_includes_ignores(args); end
end
