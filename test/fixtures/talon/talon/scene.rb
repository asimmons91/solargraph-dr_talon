module Talon
  # A collection of {GameObject}s that make up one screen or level of a
  # {Game}. Subclass it to declare scene state and {.on_enter} / {.on_exit}
  # callbacks.
  #
  # Objects spawned or destroyed during a tick are added or removed at a tick
  # boundary, so iterating the scene is always safe.
  #
  # Scene state is keyed by the scene's class and cleared on {#teardown}, so
  # entering a new instance of a scene starts from its defaults.
  #
  # @example
  #   class Level < Talon::Scene
  #     state :score, default: 0
  #
  #     on_enter do
  #       spawn(:player) { |go| go.add(Mover) }
  #     end
  #
  #     on_exit { puts "Final score: #{score}" }
  #   end
  class Scene
    attr_dr

    include Enumerable
    include Stateful
    include Callbacks

    # @return [Game, nil] the game running this scene, set when it is entered
    attr_accessor :game

    # Registers callbacks to run when a {Game} enters the scene, before its
    # first {#tick}. Typically used to spawn the scene's game objects.
    #
    # @param method_names [Array<Symbol>] instance methods to call
    # @yield [args] optional callback, evaluated on the scene
    # @yieldparam args [GTK::Args] the current DragonRuby args (omit the
    #   parameter to ignore it)
    # @return [void]
    # @see Callbacks::ClassMethods#set_callback
    def self.on_enter(*method_names, &block)
      set_callback(:enter, *method_names, &block)
    end

    # Registers callbacks to run when the scene is torn down, before its game
    # objects are destroyed and its state is cleared.
    #
    # @param method_names [Array<Symbol>] instance methods to call
    # @yield [args] optional callback, evaluated on the scene
    # @yieldparam args [GTK::Args] the current DragonRuby args (omit the
    #   parameter to ignore it)
    # @return [void]
    # @see Callbacks::ClassMethods#set_callback
    def self.on_exit(*method_names, &block)
      set_callback(:exit, *method_names, &block)
    end

    # @param state_values [Hash{Symbol => Object}] initial values for
    #   declared state
    # @raise [ArgumentError] if a keyword isn't a declared state value
    def initialize(**state_values)
      assign_state(state_values)

      # @type [Array<GameObject>]
      @game_objects = []

      # @type [Array<GameObject>]
      @incoming = []

      # @type [Array<GameObject>]
      @outgoing = []
    end

    # Sets the DragonRuby args for this scene and its game objects. Called by
    # {Game#tick}.
    #
    # @param value [GTK::Args]
    # @return [void]
    def args=(value)
      super
      @game_objects.each { |e| e.args = value }
      @incoming.each { |e| e.args = value }
    end

    # Iterates the game objects in the scene, not including those spawned
    # since the last {#tick}.
    #
    # @yieldparam game_object [GameObject]
    # @return [self, Enumerator]
    def each(&block)
      return enum_for(:each) unless block

      @game_objects.each(&block)
      self
    end

    # Creates a game object in this scene. It starts updating on the next
    # {#tick}.
    #
    # @param name [Symbol, String] unique name within the scene
    # @param prefabs [Array<#call>] objects called with the new game object,
    #   in order, before the block, typically to add a reusable set of
    #   components
    # @param attrs [Hash{Symbol => Object}] passed to {GameObject#initialize}
    #   (+tags:+ and state values)
    # @yieldparam game_object [GameObject] the new object, for adding components
    # @return [GameObject]
    # @raise [ArgumentError] if an attribute isn't +tags:+ or declared state
    def spawn(name, *prefabs, **attrs, &block)
      game_object = GameObject.new(name, scene: self, **attrs) do |g|
        prefabs.each { |prefab| prefab.call(g) }
        block&.call(g)
      end

      @incoming << game_object
      game_object
    end

    # Queues a game object for removal at the end of the current tick, when
    # its components' +on_destroy+ callbacks run and its state is cleared.
    # Objects that are already queued or destroyed are ignored.
    #
    # @param game_object [GameObject]
    # @return [void]
    def destroy(game_object)
      return if game_object.destroyed? || @outgoing.include?(game_object)

      @outgoing << game_object
    end

    # Advances the scene one frame: adds newly spawned objects, updates and
    # then draws every object, and removes destroyed objects. Called by
    # {Game#tick}.
    #
    # A destroyed object's state is kept if an object that remains in the
    # scene has the same name, such as one respawned in the same tick, since
    # the two share it.
    #
    # @return [void]
    def tick
      @game_objects.concat(@incoming)
      @incoming.clear

      each { |e| e.update }
      each { |e| e.draw }

      # Loops because +on_destroy+ callbacks may destroy further objects.
      until @outgoing.empty?
        removing = @outgoing
        @outgoing = []
        @game_objects -= removing
        @incoming -= removing
        names = (@game_objects + @incoming).map(&:name)
        removing.each { |e| e.teardown(forget_state: !names.include?(e.name)) }
      end
    end

    # Runs the scene's {.on_exit} callbacks, tears down every game object,
    # empties the scene, and then clears the scene's state and that of its
    # objects and components from +args.state+. Called by {Game#tick} when
    # switching scenes.
    #
    # @return [void]
    def teardown
      run_callbacks(:exit, args)

      (@game_objects + @incoming).each { |e| e.teardown }
      @game_objects.clear
      @incoming.clear
      @outgoing.clear
      clear_state
    end

    private

    def clear_state
      return unless args

      key = self.class.name.to_sym
      args.state.scenes&.delete(key)
      args.state.objects&.delete(key)
      args.state.components&.delete(key)
    end

    def state_store
      scenes = args.state.scenes ||= {}
      scenes[self.class.name.to_sym] ||= {}
    end
  end
end
