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
      param_types, return_type = @type_enforcements[method_name]
      decorate(method_name, param_types, return_type)
    ensure
      @applying_enforcement = false
    end
  end

  private

  def decorate(method_name, param_types, return_type)
    original_method = instance_method(method_name)
    method_parameters = original_method.parameters

    define_method(method_name) do |*args, **kwargs|
      p "args: #{args}"
      p "kwargs: #{kwargs}"
      p "method_parameters: #{method_parameters}"
      p "param_types: #{param_types}"
      p "return_type: #{return_type}"
      validated_args = []
      validated_kwargs = {}
      rest_type = nil
      keyrest_type = nil

      # Count required parameters
      req_count = method_parameters.count { |param_type, _| param_type == :req }
      rest_index = method_parameters.index { |param_type, _| param_type == :rest }

      # param_type: :opt, :req, :rest, :key, :keyreq, :keyrest
      # example:
      # def complex1(a = 1, *b, c, d:, e: nil, **f)
      # method_parameters: [[:opt, :a], [:rest, :b], [:req, :c], [:keyreq, :d], [:key, :e], [:keyrest, :f]]
      #   opt: optional positional argument (a = 1)
      #   req: required positional argument (c)
      #   rest: rest argument (*b)
      #   key: keyword argument (e:)
      #   keyreq: required keyword argument (d:)
      #   keyrest: rest keyword argument (**f)
      method_parameters.each_with_index do |(param_type, param_name), index|
        case param_type
        when :req
          value = args[index]
          type = param_types[param_name]
          validated_args << (type ? type[value] : value)
        when :rest
          rest_type = param_types[param_name]
        when :opt
          value = args[index] if index < args.length
          type = param_types[param_name]
          validated_args << (type && value ? type[value] : value) if value
        when :keyreq, :key
          value = kwargs[param_name]
          type = param_types[param_name]
          validated_kwargs[param_name] = type ? type[value] : value
        when :keyrest
          keyrest_type = param_types[param_name]
        end
      end

      # Correctly handle rest args (*b)
      if rest_index
        rest_args = args[req_count...(args.size - 1)] # Correct slicing for *b
        if rest_type
          validated_args.insert(rest_index, *rest_args.map { |v| rest_type[v] })
        else
          validated_args.insert(rest_index, *rest_args)
        end
      end

      # Handle the last positional argument (c)
      last_arg_value = args.last
      last_arg_name = method_parameters[req_count][1] # Get the name of c
      last_arg_type = param_types[last_arg_name]
      validated_args << (last_arg_type ? last_arg_type[last_arg_value] : last_arg_value)

      # Handle keyrest args (**f)
      if keyrest_type
        kwargs.each do |k, v|
          validated_kwargs[k] = keyrest_type[v] unless validated_kwargs.key?(k)
        end
      else
        validated_kwargs.merge!(kwargs.reject { |k, _| validated_kwargs.key?(k) })
      end

      # Call the original method with validated arguments
      result = original_method.bind(self).call(*validated_args, **validated_kwargs)

      # Validate return value
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
