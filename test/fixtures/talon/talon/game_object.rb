module Talon
  # A named entity in a {Scene}, made up of {Component}s. Game objects are
  # usually created with {Scene#spawn}.
  #
  # The name keys the object's {Stateful} values (and those of its
  # components) in +args.state+, so it should be unique within its scene and
  # stable across reloads. That state is cleared when the object is removed
  # from its scene, so a later object with the same name starts fresh.
  #
  # Every object is also a sprite ({StateSprite}): its position, size, path
  # and other sprite attributes are state values, so they can be passed to
  # {#initialize} or {Scene#spawn} as keywords, and the object itself can be
  # pushed to +args.outputs.sprites+.
  #
  # @example
  #   player = scene.spawn(:player, x: 100, y: 100, w: 32, h: 32,
  #                        path: "sprites/player.png")
  #   args.outputs.sprites << player
  class GameObject
    attr_dr

    include Stateful
    include StateSprite

    # @return [Scene, nil] the scene this object belongs to
    attr_accessor :scene

    # @return [Symbol, String] the object's name, unique within its scene
    attr_reader :name

    # @return [Array<Symbol>] labels for grouping and lookup
    attr_reader :tags

    # @param value [Boolean] whether the object and its components should
    #   update and draw
    # @return [Boolean]
    attr_writer :active

    # @param name [Symbol, String] unique name within the scene
    # @param scene [Scene, nil] the owning scene
    # @param tags [Array<Symbol>] labels for grouping and lookup
    # @param state_values [Hash{Symbol => Object}] initial values for
    #   declared state, including sprite attributes such as +x:+ and +path:+
    # @yieldparam game_object [GameObject] the new object, for adding components
    # @raise [ArgumentError] if a keyword isn't a declared state value
    def initialize(name, scene: nil, tags: [], **state_values)
      assign_state(state_values)

      @name = name
      @scene = scene
      @tags = tags
      @active = true

      @destroyed = false

      # @type [Array<Component>]
      @components = []
      self.args = scene.args if scene

      # Attached components whose +on_start+ hasn't run yet.
      # @type [Array<Component>]
      @fresh = []

      # @type [Array<Component>]
      @updaters = []

      # @type [Array<Component>]
      @drawers = []

      yield self if block_given?
    end

    # Sets the DragonRuby args for this object and its components.
    #
    # @param value [GTK::Args]
    # @return [void]
    def args=(value)
      super
      @components.each { |c| c.args = value }
    end

    # @return [Array<Component>] the attached components, in the order they
    #   were added
    def components
      @components.dup
    end

    # @return [Boolean] whether the object has been torn down
    def destroyed?
      @destroyed
    end

    # @return [Boolean] whether the object and its components update and draw
    def active?
      @active
    end

    # @param tag [Symbol]
    # @return [Boolean] whether {#tags} includes +tag+
    def tagged?(tag)
      @tags.include?(tag)
    end

    # Builds a component and attaches it to this object.
    #
    # @param klass [Class<Component>]
    # @param props [Hash{Symbol => Object}] passed to the component's constructor
    # @return [self]
    def add(klass, **props)
      self << klass.new(**props)
    end

    # Attaches an already-built component to this object. Its +on_start+
    # callbacks run on the object's next {#update} while it is enabled, and
    # it isn't updated or drawn until they have.
    #
    # @param component [Component]
    # @return [self]
    def <<(component)
      component.go = self
      component.args = args
      @components << component
      @fresh << component
      self
    end

    # Looks up an attached component by class, preferring the first one of
    # exactly that class and falling back to the first instance of a
    # subclass.
    #
    # @param klass [Class<Component>]
    # @return [Component, nil]
    def [](klass)
      @components.find { |c| c.instance_of?(klass) } || @components.find { |c| c.is_a?(klass) }
    end

    # Runs +on_start+ for enabled components that haven't started, then
    # updates every started, enabled component. Disabled components start
    # once they are enabled. Does nothing while the object is inactive.
    # Called by {Scene#tick}.
    #
    # @return [void]
    def update
      return unless active?

      start_components unless @fresh.empty?

      @updaters.each { |c| c.update(args) if c.enabled? }
    end

    # Draws every started, enabled component. Does nothing while the object
    # is inactive. Called by {Scene#tick}.
    #
    # @return [void]
    def draw
      return unless active?

      @drawers.each { |c| c.draw(args) if c.enabled? }
    end

    # Queues this object for removal from its scene at the end of the
    # current tick.
    #
    # @return [void]
    # @see Scene#destroy
    def destroy
      scene.destroy(self)
    end

    # Runs every component's +on_destroy+ callbacks, then clears the object's
    # and its components' state from +args.state+. Only the first call has
    # any effect. Called by the scene when the object is removed; use
    # {#destroy} to remove an object.
    #
    # @param forget_state [Boolean] whether to clear the state; the scene
    #   passes false when another object in it has the same name
    # @return [void]
    def teardown(forget_state: true)
      return if @destroyed

      @destroyed = true
      @components.each { |c| c.run_callbacks(:destroy, args) }
      clear_state if forget_state
    end

    private

    def start_components
      starting = @fresh.select(&:enabled?)
      return if starting.empty?

      @fresh -= starting
      starting.each do |c|
        c.run_callbacks(:start, args)
        @updaters << c if c.respond_to?(:update)
        @drawers << c if c.respond_to?(:draw)
      end
    end

    def clear_state
      return unless scene && args

      scene_key = scene.class.name.to_sym
      args.state.objects&.[](scene_key)&.delete(name)
      args.state.components&.[](scene_key)&.delete(name)
    end

    def state_store
      raise "#{name.inspect} state read before it was added to a scene" unless scene

      scenes = args.state.objects ||= {}
      objects = scenes[scene.class.name.to_sym] ||= {}
      objects[name] ||= {}
    end
  end
end
