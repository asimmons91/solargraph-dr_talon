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
        return true unless receiver.nil? && DSLS.key?(dsl) && attribute&.type == :sym

        host = Host.namespace(region)
        return true unless host

        name = attribute.children[0].to_s
        comments = attribute_comments(dsl, options)
        reader = method_pin(host, name, comments)
        writer = method_pin(host, "#{name}=", comments)
        writer.parameters.push Solargraph::Pin::Parameter.new(name: "value", decl: :arg, closure: writer, source: :dr_talon)
        if reader.return_type.defined?
          writer.docstring.add_tag YARD::Tags::Tag.new(:param, "", reader.return_type.items.map(&:rooted_tags), "value")
        end
        pins.push reader, writer
        true
      end

      private

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
      # @return [String]
      def attribute_comments(dsl, options)
        comments = comments_for(node).to_s
        comments = "#{DSLS[dsl]}: `#{region.code_for(node)}`" if comments.strip.empty?
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
