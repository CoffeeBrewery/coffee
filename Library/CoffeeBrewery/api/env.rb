# typed: strict
# frozen_string_literal: true

require "utils/shell"

module CoffeeBrewery
  module API
    sig { type_parameters(:U).params(block: T.proc.returns(T.type_parameter(:U))).returns(T.type_parameter(:U)) }
    def self.with_no_api_env(&block)
      return yield if CoffeeBrewery::EnvConfig.no_install_from_api?

      Utils::Shell.with_env(COFFEEBREWER_NO_INSTALL_FROM_API:                   "1",
                            COFFEEBREWER_AUTOMATICALLY_SET_NO_INSTALL_FROM_API: "1", &block)
    end

    sig {
      type_parameters(:U).params(
        condition: T::Boolean,
        block:     T.proc.returns(T.type_parameter(:U)),
      ).returns(T.type_parameter(:U))
    }
    def self.with_no_api_env_if_needed(condition, &block)
      return yield unless condition

      with_no_api_env(&block)
    end
  end
end
