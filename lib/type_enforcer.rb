# frozen_string_literal: true

module TypeEnforcer
  def self.extended(base)
    base.instance_variable_set(:@type_enforcements, {})
    base.instance_variable_set(:@applying_enforcement, false)
  end

  def enforce_types(method_name, param_types, return_type = nil)
    @type_enforcements[method_name] = [param_types, return_type]
  end

  def method_added(method_name) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    super
    return if @applying_enforcement
    return unless @type_enforcements.key?(method_name)

    @applying_enforcement = true
    begin
      param_types, return_type = @type_enforcements[method_name]
      original_method = instance_method(method_name)

      define_method(method_name) do |*args|
        if args.length != param_types.length
          raise ArgumentError, "Wrong number of arguments (given #{args.length}, expected #{param_types.length})"
        end

        validated_args = args.each_with_index.map do |arg, index|
          param_types[index][arg]
        end

        result = original_method.bind(self).call(*validated_args)

        return_type ? return_type[result] : result
      end
    ensure
      @applying_enforcement = false
    end
  end
end

# require 'dry-types'
# require 'dry-struct'

# module Types
#   include Dry.Types()

#   NonEmptyString = Types::Strict::String.constrained(min_size: 1)
#   PositiveInteger = Types::Coercible::Integer.constrained(gt: 0)

#   class User < Dry::Struct
#     attribute :name, Types::Strict::String
#     attribute :age, PositiveInteger
#   end
# end

# class Calculator
#   extend TypeEnforcer

#   enforce_types :add, [Types::Strict::Integer, Types::Strict::Integer], Types::Strict::Integer
#   enforce_types :subtract, [Types::Strict::Integer, Types::Strict::Integer], Types::Strict::Integer

#   def add(a, b)
#     a + b
#   end

#   def subtract(a, b)
#     a - b
#   end
# end

# puts Calculator.new.add(1, 2) # => 3
# puts Calculator.new.subtract(1, 2) # => -1
# puts Calculator.new.subtract(1, '2') # => "2" violates constraints (type?(Integer, "2") failed)
