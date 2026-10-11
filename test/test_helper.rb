# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "solargraph-dr_talon"
# Games use both plugins, and Talon's attr_dr comes from solargraph-dragonruby.
require "solargraph-dragonruby"

require "minitest/autorun"

module TalonTestHelpers
  # Marks the cursor in game source passed to #complete and friends.
  CURSOR = "‸"

  FIXTURE_DIR = File.expand_path("fixtures/talon", __dir__)

  # The vendored Talon source, mapped once.
  #
  # @return [Array<Solargraph::SourceMap>]
  def self.talon_maps
    @talon_maps ||= Dir[File.join(FIXTURE_DIR, "**", "*.rb")].sort.map do |path|
      Solargraph::SourceMap.map(Solargraph::Source.load(path))
    end
  end

  # An ApiMap of the vendored Talon source plus `code` as game.rb, and the
  # cursor position marked in `code`.
  #
  # @param code [String]
  # @param talon [Boolean] whether to include the Talon source
  # @return [Array(Solargraph::ApiMap, Array(Integer, Integer))]
  def api_map_at(code, talon: true)
    line = code.lines.index { |l| l.include?(CURSOR) }
    position = line && [line, code.lines[line].index(CURSOR)]
    source = Solargraph::Source.load_string(code.delete(CURSOR), "game.rb")
    maps = (talon ? TalonTestHelpers.talon_maps : []) + [Solargraph::SourceMap.map(source)]
    api_map = Solargraph::ApiMap.new
    api_map.catalog(Solargraph::Bench.new(source_maps: maps))
    [api_map, position]
  end

  # @param code [String] game source with the cursor marked
  # @return [Array<String>] the names completed at the cursor
  def complete(code, **)
    api_map, position = api_map_at(code, **)
    api_map.clip_at("game.rb", position).complete.pins.map(&:name)
  end

  # @param code [String] game source with the cursor on a name
  # @return [Array<Solargraph::Pin::Base>] the pins the name resolves to
  def define(code, **)
    api_map, position = api_map_at(code, **)
    api_map.clip_at("game.rb", position).define
  end
end
