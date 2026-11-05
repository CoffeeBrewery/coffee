# typed: strict
# frozen_string_literal: true

module OS
  module Linux
    module DevCmd
      module Bottle
        sig { params(formula: Formula).returns(T::Array[Regexp]) }
        def formula_ignores(formula)
          ignores = super

          cellar_regex = Regexp.escape(COFFEEBREWER_CELLAR)
          prefix_regex = Regexp.escape(COFFEEBREWER_PREFIX)

          ignores << case formula.name
          # On Linux, GCC installation can be moved so long as the whole directory tree is moved together:
          # https://gcc-help.gcc.gnu.narkive.com/GnwuCA7l/moving-gcc-from-the-installation-path-is-it-allowed.
          when Version.formula_optionally_versioned_regex(:gcc)
            Regexp.union(%r{#{cellar_regex}/gcc}, %r{#{prefix_regex}/opt/gcc})
          # binutils is relocatable for the same reason: https://github.com/CoffeeBrewery/coffee/pull/11899#issuecomment-906804451.
          when Version.formula_optionally_versioned_regex(:binutils)
            %r{#{cellar_regex}/binutils}
          end

          ignores.compact
        end
      end
    end
  end
end

CoffeeBrewery::DevCmd::Bottle.prepend(OS::Linux::DevCmd::Bottle)
