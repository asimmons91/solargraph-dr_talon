# frozen_string_literal: true

module Solargraph
  module DrTalon
    # Maps Talon's attribute DSLs to reader and writer pins:
    #
    #   prop :speed, default: 2    # Talon::Configurable
    #   state :score, default: 0   # Talon::Stateful
    #
    # A `@return` tag in the comment above the call sets the type; otherwise
    # it's inferred from a literal `default:`.
    #
    # It also unrolls declarations made in a loop over a list of symbols, as
    # Talon::StateSprite does for its sprite attributes:
    #
    #   ATTRIBUTES = [:x, :y, :w, :h].freeze
    #   ATTRIBUTES.each { |name| state name }
    #
    # The list must be a literal array of symbols, or a constant assigned one
    # earlier in the same file.
    #
    # This is a node processor rather than a Convention#local because
    # Solargraph 0.61 doesn't notice when a file's convention pins change, so
    # adding or removing a declaration wouldn't take effect until a restart.
    class AttributeNode < Solargraph::Parser::NodeProcessor::Base
      DSLS = {
        prop: "Talon prop",
        state: "Talon state value, stored in `args.state`"
      }.freeze

      # Literal node types and the type of the value they produce.
      LITERAL_TYPES = {
        int: "Integer",
        float: "Float",
        rational: "Rational",
        str: "String",
        dstr: "String",
        sym: "Symbol",
        dsym: "Symbol",
        # standard:disable Lint/BooleanSymbol -- these are AST node types
        true: "Boolean",
        false: "Boolean",
        # standard:enable Lint/BooleanSymbol
        array: "Array",
        hash: "Hash",
        irange: "Range",
        erange: "Range"
      }.freeze

      # Runs after Solargraph's own SendNode, which has already processed the
      # children, so this only adds the attribute pins.
      #
      # @return [Boolean] true, so later :send processors still run
      def process
        receiver, dsl, attribute, *options = node.children
        return true unless receiver.nil? && DSLS.key?(dsl)

        if attribute&.type == :sym
          host = Host.namespace(region)
          push_accessors(host, attribute.children[0].to_s, dsl, options, region.code_for(node)) if host
        elsif (names = iterated_names(attribute))
          # The loop's block is the closure; the host is around it.
          host = Host.namespace(region.update(closure: region.closure.closure))
          names.each { |name| push_accessors(host, name.to_s, dsl, options, "#{dsl} :#{name}") } if host
        end
        true
      end

      private

      # @param host [Solargraph::Pin::Namespace]
      # @param name [String]
      # @param dsl [Symbol]
      # @param options [Array<Parser::AST::Node>]
      # @param declaration [String] the declaration's code, for undocumented
      #   attributes
      # @return [void]
      def push_accessors(host, name, dsl, options, declaration)
        comments = attribute_comments(dsl, options, declaration)
        reader = method_pin(host, name, comments)
        writer = method_pin(host, "#{name}=", comments)
        writer.parameters.push Solargraph::Pin::Parameter.new(name: "value", decl: :arg, closure: writer, source: :dr_talon)
        if reader.return_type.defined?
          writer.docstring.add_tag YARD::Tags::Tag.new(:param, "", reader.return_type.items.map(&:rooted_tags), "value")
        end
        pins.push reader, writer
      end

      # The names a declaration like `state name` declares when it's directly
      # inside `LIST.each { |name| ... }`.
      #
      # @param attribute [Parser::AST::Node, nil]
      # @return [Array<Symbol>, nil]
      def iterated_names(attribute)
        return unless attribute&.type == :lvar

        block = region.closure
        return unless block.is_a?(Solargraph::Pin::Block) && block.node

        call, args = block.node.children
        return unless call.type == :send && call.children[1] == :each && call.children.length == 2

        params = args.children
        return unless params.length == 1 && params[0].type == :arg && params[0].children[0] == attribute.children[0]

        symbol_list(call.children[0])
      end

      # @param list [Parser::AST::Node, nil] a literal array of symbols, or a
      #   constant assigned one earlier in this file, optionally frozen
      # @return [Array<Symbol>, nil]
      def symbol_list(list)
        list = unfreeze(list)
        list = unfreeze(constant_value(list)) if list&.type == :const
        return unless list&.type == :array && list.children.all? { |item| item.type == :sym }

        list.children.map { |item| item.children[0] }
      end

      # @param node [Parser::AST::Node, nil]
      # @return [Parser::AST::Node, nil] the receiver of `.freeze`, or `node`
      def unfreeze(node)
        frozen = node&.type == :send && node.children[1] == :freeze && node.children.length == 2
        frozen ? node.children[0] : node
      end

      # @param const [Parser::AST::Node]
      # @return [Parser::AST::Node, nil] the value most recently assigned to
      #   a constant of that name in this file
      def constant_value(const)
        name = const.children[1].to_s
        pins.reverse_each.find { |pin| pin.is_a?(Solargraph::Pin::Constant) && pin.name == name }&.assignment
      end

      # @param host [Solargraph::Pin::Namespace]
      # @param name [String]
      # @param comments [String]
      # @return [Solargraph::Pin::Method]
      def method_pin(host, name, comments)
        # Talon defines these with attr_accessor and define_method inside its
        # own methods, so they're public whatever the caller's visibility.
        Solargraph::Pin::Method.new(
          location: location,
          closure: host,
          name: name,
          comments: comments,
          scope: :instance,
          visibility: :public,
          attribute: true,
          source: :dr_talon
        )
      end

      # The comment above the call, or a description of the declaration, plus
      # an inferred `@return` tag if the comment doesn't have one.
      #
      # @param dsl [Symbol]
      # @param options [Array<Parser::AST::Node>]
      # @param declaration [String]
      # @return [String]
      def attribute_comments(dsl, options, declaration)
        comments = comments_for(node).to_s
        comments = "#{DSLS[dsl]}: `#{declaration}`" if comments.strip.empty?
        return comments if comments.match?(/^\s*@return\b/)

        type = inferred_type(options)
        type ? "#{comments}\n@return [#{type}]" : comments
      end

      # @param options [Array<Parser::AST::Node>]
      # @return [String, nil]
      def inferred_type(options)
        default = default_value(options)
        return unless default
        return LITERAL_TYPES[default.type] if LITERAL_TYPES.key?(default.type)

        # Foo.new(...)
        receiver, method = default.children
        if default.type == :send && method == :new && receiver&.type == :const
          region.code_for(receiver)
        end
      end

      # @param options [Array<Parser::AST::Node>]
      # @return [Parser::AST::Node, nil]
      def default_value(options)
        hash = options.last
        return unless hash&.type == :hash || hash&.type == :kwargs

        pair = hash.children.find do |child|
          child.type == :pair && child.children[0].type == :sym && child.children[0].children[0] == :default
        end
        pair&.children&.last
      end
    end
  end
end
