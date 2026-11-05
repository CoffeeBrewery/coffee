# typed: strict
# frozen_string_literal: true

module RuboCop
  module Cop
    module CoffeeBrewery
      # Enforces the use of `CoffeeBrewery::API.formula_name?`/`CoffeeBrewery::API.cask_token?`
      # over membership checks on `CoffeeBrewery::API.formula_names`/`CoffeeBrewery::API.cask_tokens`,
      # which allocate and linearly scan an array of every name in the API.
      #
      # ### Example
      #
      # ```ruby
      # # bad
      # CoffeeBrewery::API.formula_names.include?(name)
      # CoffeeBrewery::API.cask_tokens.exclude?(token)
      #
      # # good
      # CoffeeBrewery::API.formula_name?(name)
      # !CoffeeBrewery::API.cask_token?(token)
      # ```
      class ApiNameMembership < Base
        extend AutoCorrector

        MSG = "Use `CoffeeBrewery::API.%<predicate>s` instead of scanning `CoffeeBrewery::API.%<list>s`."

        RESTRICT_ON_SEND = [:include?, :exclude?].freeze

        PREDICATES = T.let({
          formula_names: "formula_name?",
          cask_tokens:   "cask_token?",
        }.freeze, T::Hash[Symbol, String])

        def_node_matcher :api_name_membership?, <<~PATTERN
          (send
            (send
              $(const (const {nil? cbase} :CoffeeBrewery) :API) ${:formula_names :cask_tokens})
            {:include? :exclude?} $_)
        PATTERN

        sig { params(node: RuboCop::AST::SendNode).void }
        def on_send(node)
          return unless (api, list, arg = api_name_membership?(node))

          predicate = PREDICATES.fetch(list)
          add_offense(node, message: format(MSG, predicate:, list:)) do |corrector|
            negation = (node.method_name == :exclude?) ? "!" : ""
            corrector.replace(node, "#{negation}#{api.source}.#{predicate}(#{arg.source})")
          end
        end
      end
    end
  end
end
