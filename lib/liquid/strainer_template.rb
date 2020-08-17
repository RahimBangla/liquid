# frozen_string_literal: true

require 'set'

module Liquid
  # StrainerTemplate is the computed class for the filters system.
  # New filters are mixed into the strainer class which is then instantiated for each liquid template render run.
  #
  # The Strainer only allows method calls defined in filters given to it via StrainerFactory.add_global_filter,
  # Context#add_filters or Template.register_filter
  class StrainerTemplate
    def initialize(context)
      @context = context
    end

    class << self
      def add_filter(filter)
        return if include?(filter)

        invokable_non_public_methods = (filter.private_instance_methods + filter.protected_instance_methods).select { |m| invokable?(m) }
        if invokable_non_public_methods.any?
          raise MethodOverrideError, "Filter overrides registered public methods as non public: #{invokable_non_public_methods.join(', ')}"
        end

        include(filter)

        filter_methods.merge(filter.public_instance_methods)
      end

      def invokable?(method)
        filter_methods.include?(method.to_sym)
      end

      private

      def filter_methods
        @filter_methods ||= Set.new
      end
    end

    def invoke(method, input, *args)
      invoke_filter(method.to_sym, input, args)
    end

    # @api private
    def invoke_filter(method, input, args)
      if self.class.invokable?(method)
        send(method, input, *args)
      elsif @context.strict_filters
        raise Liquid::UndefinedFilter, "undefined filter #{method}"
      else
        input
      end
    rescue ::ArgumentError => e
      raise Liquid::ArgumentError, e.message, e.backtrace
    end
  end
end