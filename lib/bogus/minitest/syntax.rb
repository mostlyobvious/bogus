require 'forwardable'

module Bogus
  class MinitestSyntax
    extend Takes
    extend Forwardable
    takes :context
    def_delegators :context, :before, :after

    def described_class
      return context.desc if context.desc.is_a?(Module)
    end

    def described_class=(value)
      context.instance_variable_set('@desc', value)
    end

    def after_suite(&block)
      ::Minitest.after_run(&block)
    end
  end
end
