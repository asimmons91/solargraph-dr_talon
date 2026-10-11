module Talon
  # The top-level runner. Owns the active {Scene} and handles switching
  # between scenes.
  #
  # @example app/main.rb
  #   def tick(args)
  #     $game ||= Talon::Game.new(Level.new)
  #     $game.args = args
  #     $game.tick
  #   end
  class Game
    attr_dr

    include Stateful

    # @param scene [Scene] the first scene, entered on the first {#tick}
    # @param state_values [Hash{Symbol => Object}] initial values for
    #   declared state
    # @raise [ArgumentError] if a keyword isn't a declared state value
    def initialize(scene, **state_values)
      assign_state(state_values)

      @next_scene = scene
    end

    # Switches to another scene at the start of the next {#tick}. The current
    # scene is torn down and the new one's {Scene.on_enter} callbacks run
    # before it ticks.
    #
    # @param scene [Scene]
    # @return [void]
    def change_scene(scene)
      @next_scene = scene
    end

    # Advances the game one frame, performing any pending scene change and
    # then ticking the active scene. Call this from DragonRuby's +tick+ after
    # setting +args+; it is passed down to the scene, its game objects and
    # their components.
    #
    # @return [void]
    def tick
      if @next_scene
        @scene.teardown if @scene
        @scene = @next_scene
        @next_scene = nil
        @scene.game = self
        @scene.args = args
        @scene.run_callbacks(:enter, args)
      end

      @scene.args = args unless @scene.args.equal?(args)
      @scene.tick
    end

    private

    def state_store
      args.state.game ||= {}
    end
  end
end
