# frozen_string_literal: true

module TypeEnforcer
  def self.extended(base)
    base.instance_variable_set(:@type_enforcements, {})
    base.instance_variable_set(:@applying_enforcement, false)
  end

  # class Example
  #   extend TypeEnforcer
  #
  #   enforce_types :complex, {
  #     a: Types::Strict::Integer,
  #     b: Types::Strict::Array.of(String),
  #     c: Types::Strict::String.optional,
  #     d: Types::Strict::String,
  #     e: Types::Strict::Integer,
  #     kwargs: Types::Hash.map(Types::Strict::Symbol, Types::Strict::Any)
  #   }
  #
  #   def complex(a, *b, c: nil, d:, e:, **kwargs)
  #     "Positional a: #{a}, b: #{b.join(', ')}, c: #{c || 'none'}, d: #{d}, e: #{e}, kwargs: #{kwargs}"
  #   end
  # end
  def enforce_types(method_name, param_types, return_type = nil)
    @type_enforcements[method_name] = {
      params: param_types,
      return: return_type
    }
  end

  def method_added(method_name)
    super
    return if @applying_enforcement
    return unless @type_enforcements.key?(method_name)

    @applying_enforcement = true
    begin
      param_types, return_type = @type_enforcements[method_name]
      decorate(method_name, param_types, return_type)
    ensure
      @applying_enforcement = false
    end
  end

  private

  # class Example
  #   extend TypeEnforcer
  #
  #   enforce_types :complex, {
  #     a: Types::Strict::Integer,
  #     b: Types::Strict::Array.of(String),
  #     c: Types::Strict::String.optional,
  #     d: Types::Strict::String,
  #     e: Types::Strict::Integer,
  #     kwargs: Types::Hash.map(Types::Strict::Symbol, Types::Strict::Any)
  #   }
  #
  #   def complex(a, *b, c: nil, d:, e:, **kwargs)
  #     "Positional a: #{a}, b: #{b.join(', ')}, c: #{c || 'none'}, d: #{d}, e: #{e}, kwargs: #{kwargs}"
  #   end
  # end
  def decorate(method_name, param_types, return_type)
    original_method = instance_method(method_name)
    method_parameters = original_method.parameters

    define_method(method_name) do |*args, **kwargs|
      # Validate arguments
      validated_args = []
      validated_kwargs = {}

      method_parameters.each_with_index do |(param_type, param_name), index|
        case param_type
        when :req, :opt
          value = args[index]
          type = param_types[param_name]
          validated_args << (type ? type[value] : value)
        when :keyreq, :key
          value = kwargs[param_name]
          type = param_types[param_name]
          validated_kwargs[param_name] = type ? type[value] : value
        when :rest
          rest_type = param_types[param_name]
          if rest_type
            validated_args.concat(args[validated_args.length..].map { |v| rest_type[v] })
          else
            validated_args.concat(args[validated_args.length..])
          end
        when :keyrest
          keyrest_type = param_types[param_name]
          if keyrest_type
            kwargs.each do |k, v|
              validated_kwargs[k] = keyrest_type[v] unless validated_kwargs.key?(k)
            end
          else
            validated_kwargs.merge!(kwargs)
          end
        end
      end

      # Call the original method with validated arguments
      result = original_method.bind(self).call(*validated_args, **validated_kwargs)

      # Validate return value
      return_type ? return_type[result] : result
    end
  end
end

require 'dry-types'
require 'dry-struct'

module Types
  include Dry.Types()

  NonEmptyString = Types::Strict::String.constrained(min_size: 1)
  PositiveInteger = Types::Coercible::Integer.constrained(gt: 0)

  class User < Dry::Struct
    attribute :name, Types::Strict::String
    attribute :age, PositiveInteger
  end
end

# rubocop:disable Metrics/ParameterLists,Naming/MethodParameterName,Lint/MissingCopEnableDirective
class Example
  extend TypeEnforcer

  enforce_types :add, { a: Types::Strict::Integer, b: Types::Strict::Integer }, Types::Strict::Integer
  enforce_types :subtract, { a: Types::Strict::Integer, b: Types::Strict::Integer }, Types::Strict::Integer

  def add(a, b)
    a + b
  end

  def subtract(a, b)
    a - b
  end

  def complex1(a, *b, c, d:, e: nil, **kwargs)
    "a: #{a}, \nb: #{b}, \nc: #{c}, \nd: #{d}, \ne: #{e}, \nkwargs: #{kwargs}"
  end
end

puts Example.new.add(1, 2) # => 3
puts Example.new.subtract(1, 2) # => -1
# puts Example.new.subtract(1, '2') # => "2" violates constraints (type?(Integer, "2") failed)

puts 'Complex method call:'
puts Example.new.complex1(
  1, # a
  2, 2, 3, 4, # b
  5, # c
  d: 6, e: 7, # d, e
  f: 8 # kwargs
)
