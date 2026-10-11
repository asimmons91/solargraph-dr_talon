# frozen_string_literal: true

module Solargraph
  module DrTalon
    # Maps the blocks that Talon evaluates somewhere other than where they're
    # written, and defers every other block to Solargraph's BlockNode:
    #
    # * `class_methods do ... end` in a concern: its methods are defined in the
    #   concern's `ClassMethods` module (see Talon::Concern#class_methods).
    # * `included do ... end` and `prepended do ... end` in a concern: `self` is
    #   the host, so they get the concern's class side (see Convention).
    # * Lifecycle hook blocks in a class body (`on_update do ... end`, and any
    #   other bare `on_*`, `set_callback` or `define_callback` call): Talon
    #   evaluates them on an instance, so `self` is the instance. Block
    #   parameters are typed by the hook method's own `@yieldparam` tags.
    class BlockNode < Solargraph::Parser::ParserGem::NodeProcessors::BlockNode
      # Methods that register a block as an instance callback, besides `on_*`.
      CALLBACK_METHODS = %i[set_callback define_callback].freeze

      # @return [Boolean] false when this processor mapped the block, so
      #   later :block processors don't map it again
      def process
        call = node.children[0]
        return super unless call.type == :send && call.children[0].nil?

        name = call.children[1]
        concern = concern_namespace
        if name == :class_methods && call.children.length == 2 && concern
          process_class_methods(concern)
        elsif Host::CONCERN_BLOCKS.include?(name) && concern
          process_bound_block("Class<#{concern.path}>", :class, comments_for(node))
        elsif hook?(name) && (host = Host.namespace(region))
          process_bound_block(host.path, :instance, comments_for(node))
        else
          super
        end
      end

      private

      # @return [Solargraph::Pin::Namespace, nil] the module whose body this
      #   block is in
      def concern_namespace
        closure = region.closure
        closure if region.scope != :class && closure.is_a?(Solargraph::Pin::Namespace) && closure.type == :module
      end

      # @param name [Symbol]
      # @return [Boolean]
      def hook?(name)
        name.start_with?("on_") || CALLBACK_METHODS.include?(name)
      end

      # @param concern [Solargraph::Pin::Namespace]
      # @return [false]
      def process_class_methods(concern)
        class_methods = Solargraph::Pin::Namespace.new(
          type: :module,
          location: location,
          closure: concern,
          name: "ClassMethods",
          comments: comments_for(node),
          visibility: :public,
          gates: concern.gates.freeze,
          source: :dr_talon
        )
        pins.push class_methods
        body = node.children[2]
        Solargraph::Parser::NodeProcessor.process(body, region.update(closure: class_methods, visibility: :public), pins, locals, ivars)
        false
      end

      # @param context [String] the type of `self` in the block
      # @param scope [Symbol]
      # @param comments [String]
      # @return [false]
      def process_bound_block(context, scope, comments)
        block_pin = BoundBlock.new(
          location: location,
          closure: region.closure,
          node: node,
          context: Solargraph::ComplexType.try_parse(context),
          receiver: node.children[0],
          comments: comments,
          scope: scope,
          source: :dr_talon
        )
        pins.push block_pin
        process_children region.update(closure: block_pin)
        false
      end
    end

    # A block whose `self` the plugin knows from Talon's semantics. Solargraph
    # rebinds a block from its method's `@yieldreceiver` tag, but Talon's tags
    # are generic (Concern#included says `[Class]`), so this keeps the context
    # it was mapped with.
    class BoundBlock < Solargraph::Pin::Block
      # @param _api_map [Solargraph::ApiMap]
      # @return [void]
      def rebind(_api_map)
      end
    end
  end
end
