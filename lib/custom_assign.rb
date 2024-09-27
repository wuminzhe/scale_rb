def custom_assign(positional_params, keyword_params, args, kwargs = {}, defaults = {})
  assigned = {}

  # Handle positional arguments (with optional defaults)
  raise ArgumentError, 'Too many positional arguments' if args.length > positional_params.length

  positional_params.each_with_index do |param, index|
    if args[index]
      assigned[param] = args[index] # Assign from args if available
    elsif defaults.key?(param)
      assigned[param] = defaults[param] # Assign default if no argument is provided
    else
      raise ArgumentError, "Missing required positional argument: #{param}"
    end
  end

  # Handle keyword arguments (with optional defaults)
  kwargs.each_key do |key|
    raise ArgumentError, "Unknown keyword argument: #{key}" unless keyword_params.include?(key)
  end

  keyword_params.each do |key|
    if kwargs.key?(key)
      assigned[key] = kwargs[key] # Assign from kwargs if available
    elsif defaults.key?(key)
      assigned[key] = defaults[key] # Assign default if not provided
    else
      raise ArgumentError, "Missing required keyword argument: #{key}"
    end
  end

  assert_equal(positional_params.length + keyword_params.length, assigned.length)
  assigned
end

def get_method_params(method)
  params = method.parameters

  positional_params = []
  keyword_params = []

  params.each do |type, name|
    case type
    when :req, :opt # Required, optional positional arguments
      positional_params << name
    when :key, :keyreq # Keyword arguments
      keyword_params << name
    end
  end

  [positional_params, keyword_params]
end

def assert_equal(expected, actual)
  raise "Expected #{expected}, but got #{actual}" unless expected === actual
end

def build_assigned_params(method, defaults, args, kwargs)
  positional_params, keyword_params = get_method_params(method)
  custom_assign(positional_params, keyword_params, args, kwargs, defaults)
end

# def my_method(a, b = 2, c:, d: 4); end

# defaults = { b: 2, d: 4 }

# # my_method(5, c: 3)
# p build_assigned_params(:my_method, defaults, 5, c: 3)
# # => {:a=>5, :b=>2, :c=>3, :d=>4}

# # my_method(5, 6, c: 3)
# p build_assigned_params(:my_method, defaults, 5, 6, c: 3)
# # => {:a=>5, :b=>6, :c=>3, :d=>4}

# # my_method(5, 6, c: 3, d: 10)
# p build_assigned_params(:my_method, defaults, 5, 6, c: 3, d: 10)
# # => {:a=>5, :b=>6, :c=>3, :d=>10}

# # my_method(5, 6, c: 3, d: 10, e: 11)
# begin
#   build_assigned_params(:my_method, defaults, 5, 6, c: 3, d: 10, e: 11)
# rescue ArgumentError => e
#   puts e.message # => "Unknown keyword argument: e"
# end

# begin
#   build_assigned_params(:my_method, defaults, 5, 6, 7, c: 3, d: 10)
# rescue ArgumentError => e
#   puts e.message # => "Too many positional arguments"
# end
