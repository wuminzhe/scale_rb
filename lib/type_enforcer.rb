require_relative 'custom_assign'

# rubocop:disable all
module TypeEnforcer
  def self.extended(base)
    base.instance_variable_set(:@type_enforcements, {})
    base.instance_variable_set(:@applying_enforcement, false)
  end

  def sig(method_name, param_types, return_type = nil)
    @type_enforcements[method_name] = {
      params: param_types,
      return: return_type
    }
  end

  def method_added(method_name)
    super
    apply_enforcement(method_name)
  end

  def singleton_method_added(method_name)
    super
    apply_enforcement(method_name, singleton: true)
  end

  private

  def apply_enforcement(method_name, singleton: false)
    return if @applying_enforcement
    return unless @type_enforcements.key?(method_name)

    @applying_enforcement = true
    begin
      result = @type_enforcements[method_name]
      decorate(method_name, result[:params], result[:return], singleton:)
    ensure
      @applying_enforcement = false
    end
  end

  def decorate(method_name, param_types, return_type, singleton: false)
    target = singleton ? (class << self; self; end) : self
    original_method = target.instance_method(method_name)
    method_parameters = original_method.parameters

    # only support positional args and keyword args for now
    # TODO: support splat(rest), double splat(keyrest) args, and block
    target.define_method(method_name) do |*args, **kwargs|
      ScaleRb.logger.debug("----------------------------------------------------------")
      ScaleRb.logger.debug("method:          #{method_name}")
      ScaleRb.logger.debug("params:          args: #{args}, kwargs: #{kwargs}")
      ScaleRb.logger.debug("param kinds:     #{method_parameters}")
      ScaleRb.logger.debug("param types:     #{param_types}")

      validated_args = []
      validated_kwargs = {}

      # build a hash of param_name => value | default_value
      defaults = method_parameters.each_with_object({}) do |(_param_kind, param_name), memo|
        type = param_types[param_name]
        memo[param_name] = type.value if type.respond_to?(:value)
      end
      assigned_params = build_assigned_params(original_method, defaults, args, kwargs)
      ScaleRb.logger.debug("assigned params: #{assigned_params}")

      # validate each param
      method_parameters.each do |param_kind, param_name|
        case param_kind
        when :req, :opt
          value = assigned_params[param_name]
          type = param_types[param_name]
          validated_args << type[value]
        when :keyreq, :key
          value = assigned_params[param_name]
          type = param_types[param_name]
          validated_kwargs[param_name] = type[value]
        when :rest, :keyrest
          raise NotImplementedError, 'rest and keyrest args not supported'
        end
      end

      result = original_method.bind(self).call(*validated_args, **validated_kwargs)

      return_type ? return_type[result] : result
    end
  end
end

# require 'dry-types'

# module Types
#   include Dry.Types()
# end

# class Example
#   extend TypeEnforcer

#   sig :add, { a: Types::Strict::Integer, b: Types::Strict::Integer }, Types::Strict::Integer
#   def self.add(a, b)
#     a + b
#   end

#   sig :subtract, { a: Types::Strict::Integer, b: Types::Strict::Integer }, Types::Strict::Integer
#   def subtract(a, b)
#     a - b
#   end

#   sig :my_method, {
#     a: Types::Strict::Integer,
#     b: Types::Strict::Integer.default(2),
#     c: Types::Strict::Integer,
#     d: Types::Strict::Integer.default(4)
#   }, Types::Strict::String
#   def my_method(a, b = 2, c:, d: 4)
#     "a: #{a}, b: #{b}, c: #{c}, d: #{d}"
#   end
# end

# puts Example.add(1, 2) # => 3

# puts Example.new.subtract(3, 1) # => 2

# begin
#   puts Example.new.subtract(3, '1')
# rescue StandardError => e
#   puts e.class # => Dry::Types::ConstraintError
#   puts e.message # => "1" violates constraints (type?(Integer, "1") failed)
# end

# puts Example.new.my_method(5, c: 3) # => "a: 5, b: 2, c: 3, d: 4"
# puts Example.new.my_method(5, 6, c: 3) # => "a: 5, b: 6, c: 3, d: 4"
# puts Example.new.my_method(5, 6, c: 3, d: 10) # => "a: 5, b: 6, c: 3, d: 10"
# begin
#   puts Example.new.my_method(5, 6, c: 3, d: '10')
# rescue StandardError => e
#   puts e.class # => Dry::Types::ConstraintError
#   puts e.message # => "10" violates constraints (type?(Integer, "10") failed)
# end
# begin
#   puts Example.new.my_method(5, 6, d: 10)
# rescue StandardError => e
#   puts e.message # => Missing required keyword argument: c
# end
