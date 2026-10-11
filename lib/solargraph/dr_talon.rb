# frozen_string_literal: true

require "solargraph"
require_relative "dr_talon/version"
require_relative "dr_talon/host"
require_relative "dr_talon/block_node"
require_relative "dr_talon/attribute_node"
require_relative "dr_talon/convention"

module Solargraph
  # Solargraph plugin for the Talon game framework for DragonRuby. Talon itself
  # is indexed from the game's workspace; this plugin teaches Solargraph the
  # metaprogramming that static parsing misses.
  module DrTalon
  end
end

Solargraph::Convention.register Solargraph::DrTalon::Convention

# DrTalon::BlockNode handles `class_methods` and hook blocks itself and defers
# every other block to Solargraph's BlockNode, which it subclasses. It replaces
# that processor rather than registering beside it, because processors run in
# registration order and Solargraph's would otherwise map the block first.
Solargraph::Parser::NodeProcessor.deregister :block, Solargraph::Parser::ParserGem::NodeProcessors::BlockNode
Solargraph::Parser::NodeProcessor.register :block, Solargraph::DrTalon::BlockNode
Solargraph::Parser::NodeProcessor.register :send, Solargraph::DrTalon::AttributeNode
