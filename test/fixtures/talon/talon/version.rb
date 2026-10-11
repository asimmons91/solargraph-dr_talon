# Talon is a scene/game-object/component framework for DragonRuby.
#
# A {Game} runs one {Scene} at a time. A scene holds {GameObject}s, and each
# game object is composed of {Component}s that hold the behaviour. Values
# declared with {Stateful::ClassMethods#state} live in +args.state+, so they
# survive DragonRuby's hot reload.
module Talon
  # The current Talon release.
  # @return [String]
  VERSION = "0.1.0"
end
