module Talon
  # Declares attributes whose values are stored in DragonRuby's +args.state+
  # instead of on the Ruby object, so they survive hot reloads and can be
  # serialized with the rest of the game state.
  #
  # Each value is initialized lazily on first read, from the keyword passed to
  # the constructor if there was one, otherwise from the declared default.
  #
  # Including classes must implement a private +#state_store+ returning the
  # Hash to keep their values in.
  #
  # @example
  #   class Level < Talon::Scene
  #     state :score, default: 0
  #   end
  #
  #   level = Level.new(score: 10)
  #   level.score += 1
  module Stateful
    extend Concern

    class_methods do
      # Declares a state value and defines its reader and writer.
      #
      # @param name [Symbol]
      # @param default [Object] value used when none was passed to the
      #   constructor; shared across instances, so avoid mutable defaults
      # @return [void]
      def state(name, default: nil)
        state_defaults[name] = default
        define_method(name) { read_state(name) }
        define_method(:"#{name}=") { |value| state_store[name] = value }
      end

      # Default values for every state value declared on this class and its
      # ancestors.
      #
      # @return [Hash{Symbol => Object}]
      def state_defaults
        @state_defaults ||= superclass.respond_to?(:state_defaults) ? superclass.state_defaults.dup : {}
      end
    end

    private

    # @param values [Hash{Symbol => Object}]
    # @return [Hash{Symbol => Object}]
    def extract_state(values)
      names = self.class.state_defaults.keys
      @state_init = values.select { |name, _| names.include?(name) }
      values.reject { |name, _| names.include?(name) }
    end

    # Like {#extract_state}, but every key must be a declared state value.
    #
    # @param values [Hash{Symbol => Object}]
    # @return [void]
    # @raise [ArgumentError] if any key isn't a declared state value
    def assign_state(values)
      unknown = extract_state(values).keys
      return if unknown.empty?

      raise ArgumentError, "unknown keyword#{"s" if unknown.size > 1}: #{unknown.map(&:inspect).join(", ")}"
    end

    # The Hash that holds this object's state values. Including classes must
    # override this.
    #
    # @return [Hash]
    # @raise [NotImplementedError] if the including class doesn't override it
    def state_store
      raise NotImplementedError, "#{self.class} includes Stateful but doesn't define a state_store"
    end

    # @param name [Symbol]
    # @return [Hash{Symbol => Object}]
    def read_state(name)
      store = state_store
      return store[name] if store.key?(name)

      store[name] = (@state_init || {}).fetch(name) { self.class.state_defaults[name] }
    end
  end
end
