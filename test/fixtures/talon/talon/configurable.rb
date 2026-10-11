module Talon
  # Declares plain instance attributes with defaults that can be set from
  # keyword arguments at construction time.
  #
  # Unlike {Stateful} values, props live on the Ruby object and are not
  # persisted in +args.state+.
  #
  # @example
  #   class Sprite < Talon::Component
  #     prop :path, default: "sprites/square/blue.png"
  #     prop :w, default: 32
  #   end
  #
  #   Sprite.new(w: 64).w # => 64
  module Configurable
    extend Concern

    class_methods do
      # Declares a prop: defines a reader and writer and records its default.
      #
      # @param name [Symbol]
      # @param default [Object] value used when no keyword is given; shared
      #   across instances, so avoid mutable defaults
      # @return [void]
      def prop(name, default: nil)
        attr_accessor name
        prop_defaults[name] = default
      end

      # Default values for every prop declared on this class and its
      # ancestors.
      #
      # @return [Hash{Symbol => Object}]
      def prop_defaults
        @prop_defaults ||= superclass.respond_to?(:prop_defaults) ? superclass.prop_defaults.dup : {}
      end
    end

    private

    def assign_props(values)
      unknown = values.keys - self.class.prop_defaults.keys
      raise ArgumentError, "unknown keyword#{"s" if unknown.size > 1}: #{unknown.map(&:inspect).join(", ")}" unless unknown.empty?

      self.class.prop_defaults.merge(values).each { |name, value| send(:"#{name}=", value) }
    end
  end
end
