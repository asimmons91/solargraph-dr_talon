# frozen_string_literal: true

require "test_helper"

class Solargraph::TestDrTalon < Minitest::Test
  include TalonTestHelpers

  def test_that_it_has_a_version_number
    refute_nil ::Solargraph::DrTalon::VERSION
  end

  def test_plugin_entry_point_registers_convention_and_processors
    conventions = Solargraph::Convention.class_variable_get(:@@conventions)
    assert conventions.any? { |c| c.is_a?(Solargraph::DrTalon::Convention) }

    processors = Solargraph::Parser::NodeProcessor.class_variable_get(:@@processors)
    assert_equal [Solargraph::DrTalon::BlockNode], processors[:block]
    assert_includes processors[:send], Solargraph::DrTalon::AttributeNode
  end

  # Talon::Concern class_methods

  def test_class_methods_are_defined_in_the_concerns_class_methods_module
    api_map, = api_map_at("")
    assert_equal ["Talon::Configurable::ClassMethods#prop"],
      api_map.get_path_pins("Talon::Configurable::ClassMethods#prop").map(&:path)
    assert_empty api_map.get_path_pins("Talon::Configurable#prop")
  end

  def test_class_methods_of_talon_concerns_reach_talon_classes
    {"pro" => "prop", "prop_" => "prop_defaults", "sta" => "state", "state_" => "state_defaults",
     "set_" => "set_callback", "define_c" => "define_callback", "callbacks_" => "callbacks_for"}.each do |expr, name|
      assert_includes complete("Talon::Component.#{expr}‸"), name
    end
  end

  def test_class_methods_are_inherited_by_subclasses
    assert_includes complete("class Mover < Talon::Component\n  pro‸\nend\n"), "prop"
    assert_includes complete("class Mover < Talon::Component\nend\nMover.state_def‸\n"), "state_defaults"
    assert_includes complete("class Level < Talon::Scene\n  sta‸\nend\n"), "state"
  end

  def test_private_class_methods_stay_private
    refute_includes complete("Talon::Component.regi‸"), "register_callbacks"
  end

  def test_user_concern_class_methods
    code = <<~RUBY
      module Visible
        extend Talon::Concern
        class_methods do
          # Hides new instances.
          # @return [void]
          def hidden_by_default; end
        end
      end

      class Lamp < Talon::Component
        include Visible
        hid‸
      end
    RUBY
    assert_includes complete(code), "hidden_by_default"
    pin = define(code.sub("hid‸", "hidden_by_default‸")).first
    assert_equal "Visible::ClassMethods#hidden_by_default", pin.path
    assert_match(/Hides new instances/, pin.docstring.to_s)
  end

  def test_concern_dependencies_reach_the_host
    code = <<~RUBY
      module Glowing
        extend Talon::Concern
        class_methods do
          def glow_color; end
        end
      end

      module Visible
        extend Talon::Concern
        include Glowing
      end

      class Lamp
        include Visible
      end
      Lamp.glow‸
    RUBY
    assert_includes complete(code), "glow_color"
  end

  def test_prepended_concerns_add_class_methods
    code = <<~RUBY
      module Traced
        extend Talon::Concern
        class_methods do
          def trace_calls; end
        end
      end

      class Lamp
        prepend Traced
      end
      Lamp.trace‸
    RUBY
    assert_includes complete(code), "trace_calls"
  end

  def test_plain_modules_add_no_class_methods
    code = <<~RUBY
      module Helpers
        module ClassMethods
          def helper; end
        end
      end

      class Lamp
        include Helpers
      end
      Lamp.hel‸
    RUBY
    refute_includes complete(code), "helper"
  end

  def test_concerns_are_recognized_without_talon_in_the_workspace
    code = <<~RUBY
      module Visible
        extend Talon::Concern
        class_methods do
          def hidden_by_default; end
        end
      end

      class Lamp
        include Visible
      end
      Lamp.hid‸
    RUBY
    assert_includes complete(code, talon: false), "hidden_by_default"
  end

  # Talon::Concern included

  def test_included_block_completes_the_concerns_class_methods_and_dependencies
    code = <<~RUBY
      module Visible
        extend Talon::Concern
        include Talon::Configurable

        included do
          ‸
        end

        class_methods do
          def hidden_by_default; end
        end
      end
    RUBY
    names = complete(code.sub("‸", "hid‸"))
    assert_includes names, "hidden_by_default"
    assert_includes complete(code.sub("‸", "pro‸")), "prop"
  end

  def test_included_block_without_dependencies_does_not_assume_a_host
    code = <<~RUBY
      module Visible
        extend Talon::Concern

        included do
          pro‸
        end
      end
    RUBY
    refute_includes complete(code), "prop"
  end

  def test_props_declared_in_included_blocks_belong_to_the_concern
    code = <<~RUBY
      module Visible
        extend Talon::Concern
        included do
          prop :visible, default: true
        end
      end

      class Lamp < Talon::Component
        include Visible
      end
      Lamp.new.visi‸
    RUBY
    assert_includes complete(code), "visible"
    assert_equal "Boolean", define(code.sub("visi‸", "visible‸")).first.return_type.to_s
  end

  # prop and state

  def test_prop_defines_reader_and_writer
    code = <<~RUBY
      class Mover < Talon::Component
        prop :speed, default: 2

        def tick
          self.spe‸
        end
      end
    RUBY
    names = complete(code)
    assert_includes names, "speed"
    assert_includes names, "speed="
  end

  def test_state_defines_reader_and_writer
    code = <<~RUBY
      class Level < Talon::Scene
        state :score, default: 0
      end
      Level.new.sco‸
    RUBY
    names = complete(code)
    assert_includes names, "score"
    assert_includes names, "score="
  end

  def test_types_are_inferred_from_literal_defaults
    {
      "2" => "Integer", "0.5" => "Float", '"hi"' => "String", ":idle" => "Symbol", "true" => "Boolean",
      "[]" => "Array", "{}" => "Hash", "0..3" => "Range", "Vector.new(1, 2)" => "Vector"
    }.each do |default, type|
      code = "class Vector; end\nclass Mover < Talon::Component\n  prop :value, default: #{default}\nend\nMover.new.value‸\n"
      assert_equal type, define(code).first.return_type.to_s, default
    end
  end

  def test_return_tags_override_inference
    code = <<~RUBY
      class Mover < Talon::Component
        # Pixels per tick.
        # @return [Float]
        state :speed, default: 2
      end
      Mover.new.speed‸
    RUBY
    pin = define(code).first
    assert_equal "Float", pin.return_type.to_s
    assert_match(/Pixels per tick/, pin.docstring.to_s)
  end

  def test_undocumented_attributes_describe_their_declaration
    pin = define("class Mover < Talon::Component\n  prop :target\nend\nMover.new.target‸\n").first
    assert pin.return_type.undefined?
    assert_match(/prop :target/, pin.docstring.to_s)
  end

  def test_writer_takes_the_attribute_type
    pin = define("class Mover < Talon::Component\n  state :x, default: 0\nend\nMover.new.x‸ = 1\n").first
    assert_equal "Integer", pin.return_type.to_s
    api_map, = api_map_at("class Mover < Talon::Component\n  state :x, default: 0\nend\n")
    writer = api_map.get_method_stack("Mover", "x=").first
    assert_equal ["value"], writer.parameters.map(&:name)
    assert_equal ["Integer"], writer.docstring.tags(:param).first.types
  end

  def test_attributes_go_to_their_declaration
    pin = define("class Mover < Talon::Component\n  prop :speed\nend\nMover.new.speed‸\n").first
    assert_equal 1, pin.location.range.start.line
  end

  def test_attributes_are_inherited
    code = <<~RUBY
      class Mover < Talon::Component
        prop :speed, default: 2
      end
      class Dasher < Mover; end
      Dasher.new.spe‸
    RUBY
    assert_includes complete(code), "speed"
  end

  def test_attributes_are_public_after_private
    api_map, = api_map_at("class Mover < Talon::Component\n  private\n  prop :speed\nend\n")
    assert_equal [:public], api_map.get_method_stack("Mover", "speed").map(&:visibility)
  end

  def test_attribute_dsls_are_ignored_outside_class_bodies
    code = <<~RUBY
      class Mover < Talon::Component
        def setup
          prop :speed
        end
        on_start do
          state :hp
        end
      end
      Mover.new.‸
    RUBY
    refute_includes complete(code.sub("‸", "spe‸")), "speed"
    refute_includes complete(code.sub("‸", "h‸")), "hp"
  end

  def test_declarations_in_a_loop_over_a_constant_define_each_attribute
    code = <<~RUBY
      class Mover < Talon::Component
        AXES = %i[dx dy].freeze
        AXES.each { |axis| state axis, default: 0 }
      end
      Mover.new.d‸
    RUBY
    names = complete(code)
    assert_equal %w[dx dx= dy dy=], (names & %w[dx dx= dy dy=]).sort
    pin = define(code.sub("d‸", "dy‸")).first
    assert_match(/state :dy/, pin.docstring.to_s)
    assert_equal 2, pin.location.range.start.line
  end

  def test_declarations_in_a_loop_over_a_literal_array_define_each_attribute
    code = "class Mover < Talon::Component\n  [:speed, :heading].each do |name|\n    prop name\n  end\nend\nMover.new.‸\n"
    assert_includes complete(code.sub("‸", "spe‸")), "speed"
    assert_includes complete(code.sub("‸", "hea‸")), "heading"
  end

  def test_loop_declarations_in_included_blocks_belong_to_the_concern
    code = <<~RUBY
      module Tinted
        extend Talon::Concern
        include Talon::Stateful

        CHANNELS = [:r, :g, :b].freeze

        included do
          CHANNELS.each { |channel| state channel }
        end
      end

      class Lamp < Talon::Component
        include Tinted
      end
      Lamp.new.‸
    RUBY
    assert_includes complete(code.sub("‸", "r‸")), "r"
    assert_includes complete(code.sub("‸", "b‸")), "b="
  end

  def test_loop_declarations_need_a_known_list_of_symbols
    {
      "names.each { |name| prop name }" => "a method's result isn't known",
      "LIST.each { |name| prop name }" => "LIST isn't assigned in this file",
      "MIXED.each { |name| prop name }" => "MIXED isn't all symbols",
      "SYMS.each { |name| prop other }" => "the declaration doesn't use the block parameter",
      "SYMS.each_with_index { |name, i| prop name }" => "only each is unrolled",
      "SYMS.map { |name| prop name }" => "only each is unrolled"
    }.each do |loop, reason|
      code = "class Mover < Talon::Component\n  SYMS = [:speed]\n  MIXED = [:speed, \"heading\"]\n  #{loop}\nend\nMover.new.spe‸\n"
      refute_includes complete(code), "speed", reason
    end
  end

  def test_loop_declarations_are_ignored_inside_methods_and_hooks
    code = <<~RUBY
      class Mover < Talon::Component
        SYMS = [:speed, :hp]
        def setup
          SYMS.each { |name| prop name }
        end
        on_start do
          SYMS.each { |name| state name }
        end
      end
      Mover.new.‸
    RUBY
    refute_includes complete(code.sub("‸", "spe‸")), "speed"
    refute_includes complete(code.sub("‸", "h‸")), "hp"
  end

  # Talon::StateSprite

  def test_game_objects_have_state_sprite_attributes
    code = "go = Talon::GameObject.new(:player)\ngo.‸\n"
    {"pa" => "path", "an" => "angle", "anchor_" => "anchor_x", "w" => "w=", "blend" => "blendmode"}.each do |expr, name|
      assert_includes complete(code.sub("‸", "#{expr}‸")), name
    end
    pin = define(code.sub("‸", "path‸")).first
    assert_equal "Talon::StateSprite#path", pin.path
    assert_match(/state :path/, pin.docstring.to_s)
  end

  def test_sprite_attributes_complete_on_go_in_component_hooks
    code = "class Mover < Talon::Component\n  on_update do\n    go.‸\n  end\nend\n"
    assert_includes complete(code.sub("‸", "x‸")), "x"
    assert_includes complete(code.sub("‸", "y‸")), "y="
  end

  # lifecycle hook blocks

  def test_hook_blocks_are_evaluated_on_the_instance
    code = <<~RUBY
      class Mover < Talon::Component
        prop :speed, default: 2
        state :x, default: 0

        on_update do
          ‸
        end
      end
    RUBY
    assert_includes complete(code.sub("‸", "spe‸")), "speed"
    assert_includes complete(code.sub("‸", "self.x‸")), "x="
    assert_includes complete(code.sub("‸", "go.sce‸")), "scene"
  end

  def test_hook_blocks_get_attr_dr_helpers
    code = "class Mover < Talon::Component\n  on_draw { outputs.spr‸ }\nend\n"
    assert_includes complete(code), "sprites"
  end

  # Talon documents the yielded args with @yieldparam; the plugin keeps the
  # hook method as the block's receiver so Solargraph can apply it.
  def test_builtin_hook_args_are_gtk_args
    {"Talon::Component" => %w[on_start on_update on_draw on_destroy], "Talon::Scene" => %w[on_enter on_exit]}.each do |base, hooks|
      hooks.each do |hook|
        code = "class Thing < #{base}\n  #{hook} do |a|\n    a.outp‸\n  end\nend\n"
        assert_includes complete(code), "outputs", hook
      end
    end
  end

  def test_hook_args_types_come_from_talon
    code = "class Mover\n  on_update do |args|\n    args‸\n  end\nend\n"
    assert define(code, talon: false).first.return_type.undefined?
  end

  def test_scene_hooks
    code = <<~RUBY
      class Level < Talon::Scene
        state :score, default: 0

        on_enter do
          ‸
        end
      end
    RUBY
    assert_includes complete(code.sub("‸", "spa‸")), "spawn"
    assert_includes complete(code.sub("‸", "sco‸")), "score"
  end

  def test_custom_hooks_and_callback_methods
    code = <<~RUBY
      class Health < Talon::Component
        prop :hp, default: 3

        def self.on_hit(&block)
          set_callback(:hit, &block)
        end

        on_hit do |damage|
          ‸
        end

        set_callback(:heal) { hp‸ }
      end
    RUBY
    assert_includes complete(code.sub("‸", "h‸")), "hp"
    assert_includes complete(code.sub("‸", "").sub("hp‸", "h‸")), "hp"
  end

  def test_custom_hook_params_are_not_typed
    code = "class Health < Talon::Component\n  on_hit do |damage|\n    damage‸\n  end\nend\n"
    assert define(code).first.return_type.undefined?
  end

  def test_custom_hook_params_are_typed_by_yieldparam
    code = <<~RUBY
      class Enemy
        def armor; end
      end
      class Health < Talon::Component
        # @yieldparam enemy [Enemy]
        def self.on_hit(*method_names, &block) = set_callback(:hit, *method_names, &block)

        on_hit do |e|
          e.arm‸
        end
      end
    RUBY
    assert_includes complete(code), "armor"
  end

  def test_hook_blocks_in_included_blocks_are_evaluated_on_the_concerns_instances
    code = <<~RUBY
      module Visible
        extend Talon::Concern
        included do
          prop :visible, default: true
          on_draw { visi‸ }
        end
      end
    RUBY
    assert_includes complete(code), "visible"
  end

  def test_other_blocks_keep_their_receiver
    code = "class Mover < Talon::Component\n  Talon::GameObject.new(:p) { |go| go.tag‸ }\nend\n"
    assert_includes complete(code), "tagged?"
    code = "class Mover < Talon::Component\n  prop :speed\n  def tick\n    [1].each { spe‸ }\n  end\nend\n"
    assert_includes complete(code), "speed"
  end

  def test_hooks_inside_methods_are_not_rebound
    code = "class Mover < Talon::Component\n  def self.setup\n    on_update { pro‸ }\n  end\nend\n"
    assert_includes complete(code), "prop"
  end

  # end to end

  def test_spawn_and_add
    code = <<~RUBY
      class Mover < Talon::Component
        prop :speed, default: 2
      end

      class Level < Talon::Scene
        on_enter do
          spawn(:player) { |go| go.‸ }
        end
      end
    RUBY
    assert_includes complete(code.sub("‸", "ad‸")), "add"
    assert_includes complete(code.sub("‸", "tag‸")), "tagged?"
  end

  def test_loads_without_solargraph_dragonruby
    lib = File.expand_path("../../lib", __dir__)
    script = <<~RUBY
      require "solargraph-dr_talon"
      code = "class Mover\\n  include Talon::Configurable\\n  prop :speed, default: 2\\nend\\nMover.new.spe"
      maps = Dir[File.join(#{TalonTestHelpers::FIXTURE_DIR.inspect}, "**", "*.rb")].map { |f| Solargraph::SourceMap.load(f) }
      maps << Solargraph::SourceMap.map(Solargraph::Source.load_string(code, "game.rb"))
      api_map = Solargraph::ApiMap.new
      api_map.catalog(Solargraph::Bench.new(source_maps: maps))
      abort "loaded solargraph-dragonruby" if defined?(Solargraph::Dragonruby)
      print api_map.clip_at("game.rb", [4, 13]).complete.pins.map(&:name).include?("speed")
    RUBY
    output = IO.popen([RbConfig.ruby, "-I", lib, "-e", script], err: File::NULL, &:read)
    assert_equal "true", output
  end
end
