module Talon
  # A unit of behaviour attached to a {GameObject}. Subclass it and declare
  # props, state and lifecycle hooks.
  #
  # Props ({Configurable}) and state ({Stateful}) are both set from the
  # keywords passed to {GameObject#add}. State is stored per scene, game
  # object and component class; when an object has several components of
  # the same class, each one after the first gets its own slot, numbered in
  # the order they were added.
  #
  # Hook blocks and methods may take one parameter, which receives the
  # current DragonRuby +args+. The same object is always available inside a
  # component as +args+, along with helpers such as +outputs+ and +inputs+.
  # A hand-written +update+ or +draw+ method must accept it.
  #
  # @example
  #   class Mover < Talon::Component
  #     prop :speed, default: 2
  #     state :x, default: 0
  #
  #     on_update { self.x += speed }
  #   end
  #
  #   player.add(Mover, speed: 4)
  class Component
    attr_dr

    include Configurable
    include Stateful
    include Callbacks

    # @return [GameObject] the game object this component is attached to
    attr_reader :go

    # @param value [Boolean] whether {GameObject#update} and
    #   {GameObject#draw} should call this component
    # @return [Boolean]
    attr_writer :enabled

    # Registers callbacks to run once, on the first update after the
    # component is attached while it is enabled. The component isn't updated
    # or drawn until they have run.
    #
    # @param method_names [Array<Symbol>] instance methods to call
    # @yield [args] optional callback, evaluated on the component
    # @yieldparam args [GTK::Args] the current DragonRuby args (omit the
    #   parameter to ignore it)
    # @return [void]
    # @see Callbacks::ClassMethods#set_callback
    def self.on_start(*method_names, &block)
      set_callback(:start, *method_names, &block)
    end

    # Registers callbacks to run when the component's game object is torn
    # down, either because it was destroyed or because its scene ended.
    #
    # @param method_names [Array<Symbol>] instance methods to call
    # @yield [args] optional callback, evaluated on the component
    # @yieldparam args [GTK::Args] the current DragonRuby args (omit the
    #   parameter to ignore it)
    # @return [void]
    # @see Callbacks::ClassMethods#set_callback
    def self.on_destroy(*method_names, &block)
      set_callback(:destroy, *method_names, &block)
    end

    # Defines the component's per-tick +update+ method. Called every tick
    # while the component is enabled and its game object is active.
    #
    # @param method_names [Array<Symbol>] instance methods to call
    # @yield [args] optional callback, evaluated on the component
    # @yieldparam args [GTK::Args] the current DragonRuby args (omit the
    #   parameter to ignore it)
    # @return [void]
    # @see Callbacks::ClassMethods#define_callback
    def self.on_update(*method_names, &block)
      define_callback(:update, *method_names, &block)
    end

    # Defines the component's per-tick +draw+ method. Called every tick, after
    # all game objects have updated, while the component is enabled and its
    # game object is active.
    #
    # @param method_names [Array<Symbol>] instance methods to call
    # @yield [args] optional callback, evaluated on the component
    # @yieldparam args [GTK::Args] the current DragonRuby args (omit the
    #   parameter to ignore it)
    # @return [void]
    # @see Callbacks::ClassMethods#define_callback
    def self.on_draw(*method_names, &block)
      define_callback(:draw, *method_names, &block)
    end

    # Usually called through {GameObject#add} rather than directly.
    #
    # @param props [Hash{Symbol => Object}] initial values for declared props
    #   and state
    # @raise [ArgumentError] if a keyword isn't a declared prop or state value
    def initialize(**props)
      @enabled = true
      assign_props(extract_state(props))
    end

    # @return [Boolean] whether this component receives update and draw calls
    def enabled?
      @enabled
    end

    # Attaches the component to a game object. Called by {GameObject#<<}.
    #
    # @param value [GameObject]
    # @return [void]
    def go=(value)
      @go = value
      @state_key = nil
    end

    # @return [Scene] the scene of the game object this component is attached to
    def scene
      go.scene
    end

    private

    def state_store
      raise "#{self.class} state read before it was attached to a scene" unless go&.scene

      scenes = args.state.components ||= {}
      objects = scenes[go.scene.class.name.to_sym] ||= {}
      components = objects[go.name] ||= {}
      components[state_key] ||= {}
    end

    # The first component of a class on a game object uses the class name;
    # later ones are suffixed with their position, e.g. +:"Mover#2"+.
    def state_key
      @state_key ||= begin
        position = go.components.select { |c| c.instance_of?(self.class) }.index { |c| c.equal?(self) }
        position.zero? ? self.class.name.to_sym : :"#{self.class.name}##{position + 1}"
      end
    end
  end
end
