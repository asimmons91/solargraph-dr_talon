# solargraph-dr_talon

A [Solargraph](https://solargraph.org) plugin that gives LSP editors autocomplete, hover docs and go-to-definition
for games built with [Talon](https://github.com/asimmons91/talon), a scene/game object/component framework for
[DragonRuby](https://dragonruby.org).

Solargraph already indexes Talon's source when it's in your game. This plugin teaches it the parts of Talon that
are defined by metaprogramming:

```ruby
class Mover < Talon::Component
  prop :speed, default: 2             # speed / speed= (Integer), from prop and state
  state :x, default: 0                # prop, state, on_update, ... complete in the class body

  on_update do |args|                 # hook blocks run on the instance: self is a Mover
    self.x += speed                   # so props, state, go, scene and attr_dr helpers complete
    args.outputs.sprites << { ... }   # args is GTK::Args in Talon's built-in hooks
  end
end

module Visible
  extend Talon::Concern
  include Talon::Configurable

  included do
    prop :visible, default: true      # Lamp.new.visible completes
  end

  class_methods do
    def hidden_by_default             # Lamp.hidden_by_default completes
      prop_defaults[:visible] = false
    end
  end
end

class Lamp < Talon::Component
  include Visible
end
```

## Requirements

- A CRuby install. DragonRuby doesn't need one, but Solargraph does.
- Solargraph 0.61.x: `gem install solargraph -v '~> 0.61.0'`
- Talon's source in your Solargraph workspace, for example vendored in `mygame/lib/talon`. Vendor Talon from
  commit 6625c07 or later so hook block parameters are typed as `GTK::Args`.
- [solargraph-dragonruby](https://github.com/asimmons91/solargraph-dragonruby), recommended, for the DragonRuby
  API (`args`, `outputs`, `attr_dr`, ...). This plugin works without it, but `args`, `outputs` and the other
  DragonRuby helpers won't complete.

## Installation

Install the gems into the same Ruby that runs `solargraph`:

```sh
gem install solargraph-dragonruby solargraph-dr_talon
```

Then add both plugins to the `.solargraph.yml` in your game's root directory (`solargraph config` generates a
default one), and make sure `include` covers Talon's source:

```yml
include:
  - "mygame/**/*.rb"
plugins:
  - solargraph-dragonruby
  - solargraph-dr_talon
```

Restart your editor's language server. See solargraph-dragonruby's README for editor setup.

## What's covered

- **`Talon::Concern`**
  - Methods in a `class_methods do ... end` block are defined in the concern's `ClassMethods` module, which is how
    they exist at runtime.
  - Including or prepending a concern adds its class methods to the host, along with those of every concern it
    includes (its dependencies). Subclasses inherit them, so `prop`, `state`, `set_callback`, `prop_defaults`, ...
    complete in any subclass of `Talon::Component`, `Talon::Scene`, `Talon::GameObject` or `Talon::Game`.
  - Inside `included do ... end` (and `prepended do ... end`), `self` is the class that includes the concern, which
    can't be known statically. So the concern's own class methods and those of the concerns it includes complete
    there. To use `prop` in an `included` block, have the concern `include Talon::Configurable` (for `state`,
    `Talon::Stateful`, and for `on_*` hooks, `Talon::Callbacks`). Talon then also includes them into the host.
- **`prop` and `state`** define a reader and a writer.
  - The type comes from a `@return` tag in the comment above the call, or is inferred from a literal `default:`
    (`2` is an `Integer`, `"a"` a `String`, `true` a `Boolean`, `Vector.new(...)` a `Vector`, ...).
  - The comment becomes the hover docs, and go-to-definition jumps to the declaration.
  - A declaration in a concern's `included` block defines the methods on the concern, so every host gets them.
- **Lifecycle hook blocks** in a class body are evaluated on the instance, as Talon runs them.
  - This applies to `on_start`, `on_update`, `on_draw`, `on_destroy`, `on_enter` and `on_exit`, and to `set_callback`
    and `define_callback`.
  - It also covers any other `on_*` call, so custom hooks (`def self.on_hit(&b) = set_callback(:hit, &b)`) work
    too.
  - Block parameters are typed by the hook method's `@yieldparam` tag. Talon's built-in hooks document theirs as
    `GTK::Args` (since Talon 6625c07; older copies leave `args` untyped). Document a custom hook the same way:

    ```ruby
    # @yieldparam enemy [Enemy]
    def self.on_hit(*method_names, &block) = set_callback(:hit, *method_names, &block)
    ```

### Limitations

- The plugin recognizes Talon's DSLs by name, so it doesn't check that a class actually descends from a Talon
  class:
  - `prop :name` and `state :name` called in any class body define accessors.
  - A block passed to any bare `on_*` call in a class body is evaluated on the instance.
- A concern's own class side (`Visible.hidden_by_default`) also completes its `ClassMethods`. This is what makes
  them complete inside `included do ... end`, but calling them on the concern itself fails at runtime.
- The Talon methods behind a hook block (such as `update` from `on_update`) are generated at runtime and don't
  complete.

## Development

```sh
bin/setup                         # install dependencies
bundle exec rake                  # tests + standardrb
bundle exec rake fixtures:sync    # re-vendor Talon's lib/ into test/fixtures from main
bundle exec rake fixtures:sync[<ref>] # ...or from a specific branch, tag or commit
```

- `test/fixtures/talon` is a snapshot of Talon's `lib/` that the tests run against. `UPSTREAM` records its commit.
  After a Talon change, sync it and re-run the tests.
- The Solargraph dependency is pinned to `~> 0.61.0`, because the node processor and convention internals this
  plugin hooks into change between minor releases. Re-run the tests before widening it.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
The vendored Talon source in `test/fixtures/talon` is also MIT licensed, by Austin Simmons.
