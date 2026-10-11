## [Unreleased]

## [0.1.0] - 2026-10-11

- Initial release: a Solargraph plugin for the [Talon](https://github.com/asimmons91/talon) game framework.
- `Talon::Concern` mixins: methods in a `class_methods do ... end` block are defined in the concern's `ClassMethods`
  module, and including or prepending a concern (or a class whose superclass did) adds them, and those of the
  concerns it includes, to the host's class methods. Inside `included do ... end`, `self` gets the concern's own
  class methods and those of the concerns it includes.
- `prop` and `state` declarations define reader and writer methods, typed by a `@return` tag above the call or
  inferred from a literal `default:`. Declarations in a concern's `included` block belong to the concern.
- Lifecycle hook blocks in a class body (`on_start`, `on_update`, `on_draw`, `on_destroy`, `on_enter`, `on_exit`,
  any other `on_*`, `set_callback` and `define_callback`) are evaluated on the instance. Their block parameters
  are typed by the hook method's `@yieldparam` tag, which Talon's built-in hooks document as `GTK::Args`.

[Unreleased]: https://github.com/asimmons91/solargraph-dr_talon/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/asimmons91/solargraph-dr_talon/releases/tag/v0.1.0
