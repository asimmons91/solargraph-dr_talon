# frozen_string_literal: true

module Solargraph
  module DrTalon
    # Adds class methods from Talon::Concern mixins. Including a concern
    # extends the host with the concern's `ClassMethods`, and with those of
    # every concern it includes (its dependencies).
    #
    # Inside a concern, `self` in an `included do ... end` block is the host,
    # which can't be known statically, so the concern's own class side gets
    # its `ClassMethods` and its dependencies'.
    #
    # Resolved when methods are looked up rather than when files are parsed,
    # since whether an included module is a concern depends on other files.
    class Convention < Solargraph::Convention::Base
      CONCERN = "Talon::Concern"

      # @param api_map [Solargraph::ApiMap]
      # @param rooted_tag [String]
      # @param scope [Symbol] :class or :instance
      # @param visibility [Array<Symbol>]
      # @param deep [Boolean]
      # @param skip [Set<String>]
      # @param _no_core [Boolean]
      # @return [Solargraph::Environ]
      def object(api_map, rooted_tag, scope, visibility, deep, skip, _no_core)
        return EMPTY_ENVIRON unless scope == :class

        rooted_type = Solargraph::ComplexType.parse(rooted_tag).force_rooted
        fqns = rooted_type.namespace
        namespace_pin = api_map.get_path_pins(fqns).find { |pin| pin.is_a?(Solargraph::Pin::Namespace) }
        return EMPTY_ENVIRON unless namespace_pin

        concerns = []
        concerns << fqns if concern?(api_map, fqns)
        collect_concerns(api_map, fqns, concerns)
        return EMPTY_ENVIRON if concerns.empty?

        pins = concerns.flat_map do |concern|
          api_map.inner_get_methods_from_reference("#{concern}::ClassMethods", namespace_pin, rooted_type,
            :instance, visibility, deep, skip, true)
        end
        Solargraph::Environ.new(pins: pins)
      end

      private

      # Appends the concerns that `fqns` includes or prepends, and theirs, in
      # the order Talon includes them into a host.
      #
      # @param api_map [Solargraph::ApiMap]
      # @param fqns [String]
      # @param concerns [Array<String>]
      # @return [void]
      def collect_concerns(api_map, fqns, concerns)
        mixins(api_map, fqns).each do |ref|
          mixin = api_map.dereference(ref)
          next if mixin.nil? || concerns.include?(mixin) || !concern?(api_map, mixin)

          collect_concerns(api_map, mixin, concerns)
          concerns << mixin
        end
      end

      # @param api_map [Solargraph::ApiMap]
      # @param fqns [String]
      # @return [Array<Solargraph::Pin::Reference>]
      def mixins(api_map, fqns)
        # ApiMap has no public prepend lookup.
        api_map.get_includes(fqns) + api_map.send(:store).get_prepends(fqns)
      end

      # @param api_map [Solargraph::ApiMap]
      # @param fqns [String]
      # @return [Boolean]
      def concern?(api_map, fqns)
        api_map.get_extends(fqns).any? do |ref|
          # Fall back to the written name when Talon isn't in the workspace.
          (api_map.dereference(ref) || ref.name.delete_prefix("::")) == CONCERN
        end
      end
    end
  end
end
