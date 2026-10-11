# frozen_string_literal: true

module Solargraph
  module DrTalon
    # Finds the class or module that a Talon class-body DSL call applies to.
    module Host
      # Blocks that a Talon::Concern evaluates in the including class. A DSL
      # call inside one declares on the concern, so its hosts inherit it.
      CONCERN_BLOCKS = %i[included prepended].freeze

      module_function

      # The namespace whose class body `region` is in, looking through a
      # concern's `included`/`prepended` block. Nil inside methods, other
      # blocks, `class << self`, and at the top level.
      #
      # @param region [Solargraph::Parser::Region]
      # @return [Solargraph::Pin::Namespace, nil]
      def namespace(region)
        return if region.scope == :class

        closure = region.closure
        closure = closure.closure if concern_block?(closure)
        closure if closure.is_a?(Solargraph::Pin::Namespace) && !closure.path.empty?
      end

      # @param pin [Solargraph::Pin::Base]
      # @return [Boolean]
      def concern_block?(pin)
        return false unless pin.is_a?(Solargraph::Pin::Block) && pin.receiver&.type == :send

        receiver, name = pin.receiver.children
        receiver.nil? && CONCERN_BLOCKS.include?(name)
      end
    end
  end
end
