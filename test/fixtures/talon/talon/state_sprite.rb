module Talon
  # DragonRuby's +attr_sprite+ contract with every attribute declared as
  # {Stateful} state, so a sprite's values live in +args.state+ and survive
  # hot reloads and serialization along with the rest of the game state.
  #
  # Including classes get a reader and writer for each name in {ATTRIBUTES},
  # can be passed straight to +args.outputs.sprites+, and get the
  # +GTK::Geometry+ helpers (+intersect_rect?+, +right+, +top+, ...) that
  # +attr_sprite+ provides. Like any {Stateful} class, they must implement a
  # private +#state_store+, and the attributes can be set from constructor
  # keywords.
  #
  # Don't combine this with +attr_sprite+: DragonRuby renders +AttrSprite+
  # objects by reading their instance variables, which this module leaves
  # unset.
  #
  # @example
  #   class Body < Talon::Component
  #     include Talon::StateSprite
  #
  #     on_draw { outputs.sprites << self }
  #   end
  #
  #   player.add(Body, x: 100, y: 100, w: 32, h: 32, path: "sprites/player.png")
  #
  # @see https://docs.dragonruby.org/#/api/outputs?id=sprites DragonRuby
  #   sprite attributes
  module StateSprite
    extend Concern

    include Stateful
    include AttrRect

    # The sprite attributes declared as state, matching +attr_sprite+. All
    # default to +nil+, which DragonRuby treats as its own default.
    #
    # @return [Array<Symbol>]
    ATTRIBUTES = [
      :x, :y, :w, :h, :path, :angle, :a, :r, :g, :b, :tile_x,
      :tile_y, :tile_w, :tile_h, :flip_horizontally,
      :flip_vertically, :angle_anchor_x, :angle_anchor_y, :id,
      :angle_x, :angle_y, :z,
      :source_x, :source_y, :source_w, :source_h, :blendmode_enum,
      :source_x2, :source_y2, :source_x3, :source_y3, :x2, :y2, :x3, :y3,
      :anchor_x, :anchor_y, :r2, :g2, :b2, :a2, :r3, :g3, :b3, :a3,
      :scale_quality_enum, :blendmode
    ].freeze

    included do
      ATTRIBUTES.each { |name| state name }
    end

    # @return [Symbol] +:sprite+, so DragonRuby renders this object as a
    #   sprite
    def primitive_marker
      :sprite
    end

    # @return [self]
    def sprite
      self
    end

    # Alias for +x=+, matching +attr_sprite+.
    #
    # @param value [Numeric]
    # @return [Numeric]
    def x1=(value)
      self.x = value
    end

    # Alias for +y=+, matching +attr_sprite+.
    #
    # @param value [Numeric]
    # @return [Numeric]
    def y1=(value)
      self.y = value
    end
  end
end
