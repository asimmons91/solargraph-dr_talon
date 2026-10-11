module Talon
  # A small, dependency-free take on ActiveSupport::Concern for building mixins
  # that add class methods and run setup code when included.
  #
  # Concerns that include other concerns have their dependencies included into
  # the final host class rather than into each other, so a concern's
  # +included+ block always runs against the real host.
  #
  # @example
  #   module Visible
  #     extend Talon::Concern
  #
  #     included do
  #       prop :visible, default: true
  #     end
  #
  #     class_methods do
  #       def hidden_by_default
  #         prop_defaults[:visible] = false
  #       end
  #     end
  #   end
  module Concern
    # Initializes the dependency list on a module that extends Concern.
    #
    # @param base [Module] the module being turned into a concern
    # @return [void]
    def self.extended(base)
      base.instance_variable_set(:@_dependencies, [])
    end


    # Hook used by +Module#include+. When +base+ is itself a concern, records
    # this module as a dependency instead of including it; otherwise includes
    # dependencies, extends +ClassMethods+, and runs the {#included} block.
    #
    # @param base [Module]
    # @return [Boolean] whether the module was actually appended
    def append_features(base)
      if base.instance_variable_defined?(:@_dependencies)
        base.instance_variable_get(:@_dependencies) << self
        return false
      end

      return false if base.ancestors.include?(self)

      @_dependencies.each { |dependency| base.include(dependency) }
      super

      base.extend(const_get(:ClassMethods)) if const_defined?(:ClassMethods, false)
      base.class_eval(&@_included_block) if @_included_block
      true
    end

    # Hook used by +Module#prepend+. The prepend counterpart of
    # {#append_features}: +ClassMethods+ is prepended to the singleton class
    # and the {#prepended} block is run.
    #
    # @param base [Module]
    # @return [Boolean] whether the module was actually prepended
    def prepend_features(base)
      if base.instance_variable_defined?(:@_dependencies)
        base.instance_variable_get(:@_dependencies).unshift(self)
        return false
      end

      return false if base.ancestors.include?(self)

      @_dependencies.each { |dependency| base.prepend(dependency) }
      super

      base.singleton_class.prepend(const_get(:ClassMethods)) if const_defined?(:ClassMethods, false)
      base.class_eval(&@_prepended_block) if @_prepended_block
      true
    end

    # With a block, registers code to +class_eval+ in each class that includes
    # this concern. Without a block, behaves as the normal +Module#included+
    # hook.
    #
    # @param base [Module, nil]
    # @yieldreceiver [Class] the including class
    # @return [void]
    def included(base = nil, &block)
      return super(base) unless block

      @_included_block = block
    end

    # With a block, registers code to +class_eval+ in each class that prepends
    # this concern. Without a block, behaves as the normal +Module#prepended+
    # hook.
    #
    # @param base [Module, nil]
    # @yieldreceiver [Class] the prepending class
    # @return [void]
    def prepended(base = nil, &block)
      return super(base) unless block

      @_prepended_block = block
    end

    # Defines class methods for hosts of this concern. The block is evaluated
    # in this concern's +ClassMethods+ module (created on first use), which is
    # extended onto every including class.
    #
    # @yieldreceiver [Module] the +ClassMethods+ module
    # @return [void]
    def class_methods(&block)
      mod = const_defined?(:ClassMethods, false) ? const_get(:ClassMethods) : const_set(:ClassMethods, Module.new)
      mod.module_eval(&block)
    end
  end
end
