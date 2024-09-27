module TypeEnforcer
  def self.extended(base)
    base.instance_variable_set(:@type_enforcements, {})
    base.instance_variable_set(:@applying_enforcement, false)
  end

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
      result = @type_enforcements[method_name]
      decorate(method_name, result[:params], result[:return])
    ensure
      @applying_enforcement = false
    end
  end

  private

  def decorate(method_name, param_types, return_type)
    original_method = instance_method(method_name)
    method_parameters = original_method.parameters

    define_method(method_name) do |*args, **kwargs|
      validated_args = []
      validated_kwargs = {}
      rest_type = nil
      keyrest_type = nil

      positional_count = method_parameters.count { |param_type, _| %i[req opt].include?(param_type) }
      rest_index = method_parameters.index { |param_type, _| param_type == :rest }

      method_parameters.each_with_index do |(param_type, param_name), _index|
        case param_type
        when :req, :opt
          value = args[validated_args.length]
          type = param_types[param_name]
          validated_args << type[value]
        when :rest
          rest_type = param_types[param_name]
          validated_args.concat(rest_type[args[rest_index..(args.size - positional_count)]])
        when :keyreq, :key
          value = kwargs[param_name]
          type = param_types[param_name]
          validated_kwargs[param_name] = type[value]
        when :keyrest
          keyrest_type = param_types[param_name]
          validated_kwargs.merge!(keyrest_type[kwargs.reject { |k, _| validated_kwargs.key?(k) }])
        end
      end

      result = original_method.bind(self).call(*validated_args, **validated_kwargs)

      return_type ? return_type[result] : result
    end
  end
end

require 'dry-types'

module Types
  include Dry.Types()

  NonEmptyString = Types::Strict::String.constrained(min_size: 1)
  PositiveInteger = Types::Coercible::Integer.constrained(gt: 0)
end

class Example
  extend TypeEnforcer

  enforce_types :complex1,
                {
                  a: Types::Strict::Integer,
                  b: Types::Array.of(Types::Strict::Integer),
                  c: Types::Strict::Integer,
                  d: Types::Strict::Integer,
                  e: Types::Strict::Integer.optional,
                  f: Types::Hash.map(Types::Strict::Symbol, Types::Strict::Integer)
                }, Types::Strict::String

  def complex1(a = 1, *b, c, d:, e: nil, **f)
    "a: #{a}, b: #{b}, c: #{c}, d: #{d}, e: #{e}, f: #{f}"
  end
end

# Test case
puts Example.new.complex1(
  1,                  # a
  2, 3, 4,            # *b (rest args)
  5,                  # c
  d: 6,               # d (keyword arg)
  e: 7,               # e (optional keyword arg)
  x: 8, y: 9          # f (kwargs)
)
