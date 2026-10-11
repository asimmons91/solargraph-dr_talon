module Talon
  # Named lifecycle hooks for a class.
  #
  # Two kinds of hook are supported:
  #
  # * Chained hooks ({ClassMethods#set_callback}): any number of callbacks,
  #   inherited by subclasses, run in order by {#run_callbacks}. Used for
  #   infrequent events such as +:start+ or +:destroy+.
  # * Defined hooks ({ClassMethods#define_callback}): compiled into a single
  #   instance method named after the hook, for hot paths such as +:update+
  #   that run every tick.
  #
  # Callbacks given as a block or method name may take one argument, which
  # receives the +args+ passed when the hook runs, or none.
  module Callbacks
    extend Concern

    class_methods do
      # Appends callbacks to a chained hook. Subclasses run their parent's
      # callbacks first, then their own.
      #
      # Registrations made in a later tick than this class's previous ones for
      # the same hook replace them instead of appending, so hot-reloading a
      # file doesn't register its callbacks twice.
      #
      # @param hook [Symbol] the hook name, e.g. +:start+
      # @param method_names [Array<Symbol>] instance methods to call; each is
      #   passed the hook's +args+
      # @yield [args] optional callback, evaluated on the instance
      # @yieldparam args [Object] the value given to {Callbacks#run_callbacks}
      #   (omit the parameter to ignore it)
      # @return [void]
      def set_callback(hook, *method_names, &block)
        register_callbacks(hook, method_names, block)
      end

      # Defines an instance method named +hook+ that calls every method and
      # block registered for it on this class, in order. Each call adds to
      # the method; a subclass's definition overrides its parent's. Reloads
      # are handled as for {#set_callback}.
      #
      # @param hook [Symbol] the hook and method name, e.g. +:update+
      # @param method_names [Array<Symbol>] instance methods to call; each is
      #   passed the hook's +args+
      # @yield [args] optional callback, evaluated on the instance
      # @yieldparam args [Object] the argument the generated method is called
      #   with (omit the parameter to ignore it)
      # @return [void]
      # @raise [ArgumentError] if neither a method name nor a block is given
      def define_callback(hook, *method_names, &block)
        raise ArgumentError, "on_#{hook} needs a method name or block" if method_names.empty? && !block

        calls = register_callbacks(hook, method_names, block)

        if calls.size == 1
          target, takes_args = calls.first
          if block && takes_args
            alias_method hook, target
            public hook
          elsif takes_args
            define_method(hook) { |args| send(target, args) }
          else
            define_method(hook) { |_args| send(target) }
          end
        else
          define_chained_method(hook, calls.dup)
        end
      end

      # The full callback chain for a hook, ancestors' callbacks first.
      #
      # @param hook [Symbol]
      # @return [Array<(Symbol, Boolean)>] pairs of method name and whether
      #   the method takes the hook's +args+
      def callbacks_for(hook)
        inherited = superclass.respond_to?(:callbacks_for) ? superclass.callbacks_for(hook) : []
        inherited + (own_callbacks[hook] || [])
      end

      private

      def own_callbacks
        @own_callbacks ||= {}
      end

      def register_callbacks(hook, method_names, block)
        chain = own_chain(hook)
        method_names.each { |name| chain << [ name, true ] }
        chain << define_hook_method(hook, chain.size, block) if block
        chain
      end

      # A class body runs within a single tick, so a registration from a later
      # tick means the class is being re-evaluated by a hot reload.
      def own_chain(hook)
        generations = @callback_generations ||= {}
        generation = callback_generation
        own_callbacks[hook] = [] unless generations[hook] == generation
        generations[hook] = generation
        own_callbacks[hook]
      end

      def callback_generation
        Kernel.global_tick_count
      end

      # Defines +hook+ to call several callbacks. This runs every tick, so short
      # chains are unrolled and longer ones use an index loop; both measure
      # well ahead of +each+ with destructuring in DragonRuby.
      def define_chained_method(hook, calls)
        case calls.size
        when 2
          (m1, t1), (m2, t2) = calls
          define_method(hook) do |args|
            t1 ? send(m1, args) : send(m1)
            t2 ? send(m2, args) : send(m2)
          end
        when 3
          (m1, t1), (m2, t2), (m3, t3) = calls
          define_method(hook) do |args|
            t1 ? send(m1, args) : send(m1)
            t2 ? send(m2, args) : send(m2)
            t3 ? send(m3, args) : send(m3)
          end
        else
          names = calls.map(&:first)
          takes = calls.map(&:last)
          count = calls.size
          define_method(hook) do |args|
            i = 0
            while i < count
              takes[i] ? send(names[i], args) : send(names[i])
              i += 1
            end
          end
        end
      end

      def define_hook_method(hook, index, block)
        method_name = :"#{name}#on_#{hook}_#{index}"
        define_method(method_name, &block)
        private method_name
        [ method_name, block.arity != 0 ]
      end
    end

    # Runs every callback registered for a chained hook with
    # {ClassMethods#set_callback}.
    #
    # @param hook [Symbol]
    # @param args [Object] passed to each callback that takes an argument
    # @return [void]
    def run_callbacks(hook, args)
      self.class.callbacks_for(hook).each do |method_name, takes_args|
        takes_args ? send(method_name, args) : send(method_name)
      end
    end
  end
end
