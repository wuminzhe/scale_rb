require 'uri'
require 'net/http'
require 'json'

class String
  def to_camel
    split('_').collect(&:capitalize).join
  end
end

# types = JSON.parse(File.open('./substrate-types.json').read)
types = JSON.parse(File.open('./kusama-types.json').read)
types = types.map { |type| [type['id'], type['type']] }.to_h

def build_type_name(path, params, types, result)
  return if path.empty?

  name = path.join('::')

  return name if params.empty?

  param_names_str = params.map do |param|
    if param['type'].nil?
      param['name']
    else
      get_type(param['type'], types, result)[:name]
    end
  end.join(', ')

  # "#{name}<#{params.reduce([]) { |out, param| out << param['name'] }.join(', ')}>"
  "#{name}<#{param_names_str}>"
end

# result
# {
#   types: {
#     id => {
#       name: _,
#       def: _ # optional
#     }
#   }
#
#   name_id_map: {
#     name => id
#   }
#
# }

def get_type(id, types, result)
  # TODO: id check
  if result[:types][id].nil?
    type = build_type(types[id], types, result)

    # fix type name if need
    type[:name] = fix_type_name(id, type[:name], result[:name_id_map])
    result[:name_id_map][type[:name]] = id

    result[:types][id] = type
  end
  result[:types][id]
end

def fix_type_name(id, name, name_id_map)
  if name_id_map.key?(name)
    exist_id = name_id_map[name]
    if exist_id != id
      # different type with same name
      splits = name.split('/')
      no = splits.length > 1 ? splits.last.to_i + 1 : 1
      return get_type_name(id, "#{splits[0]}/#{no}", name_id_map)
    end
  end

  name
end

# {
#   id => {
#     name: '',
#     def: {...}
#   },
#   id => { # primitive
#     name: 'U8'
#   }
# }
def build_type(type, types, result)
  type_def = type['def']
  if type_def.key?('composite')
    build_composite(type, types, result)
  elsif type_def.key?('array')
    build_array(type_def['array'], types, result)
  elsif type_def.key?('sequence')
    build_sequence(type_def['sequence'], types, result)
  elsif type_def.key?('tuple')
    build_tuple(type_def['tuple'], types, result)
  elsif type_def.key?('variant')
    build_variant(type, types, result)
  elsif type_def.key?('primitive')
    build_primitive(type_def['primitive'])
  elsif type_def.key?('compact')
    build_compact(type_def['compact'], types, result)
  else
    { name: 'fuck*******************************************************' }
    # raise NotImplementedError
  end
end

def build_array(array_def, types, result)
  len = array_def['len']
  inner_type_id = array_def['type']

  inner_type = get_type_name(inner_type_id, types, result)
  inner_type_name = inner_type[:name]

  {
    # name: "Array#{len}Of#{inner_type_name}",
    name: "[#{inner_type_name}; #{len}]",
    def: {
      _array: {
        len: len,
        type: inner_type_name
      }
    }
  }
end

def build_sequence(sequence_def, types, result)
  inner_type_id = sequence_def['type']

  inner_type = get_type(inner_type_id, types, result)
  inner_type_name = inner_type[:name]

  {
    name: "Vec<#{inner_type_name}>",
    def: {
      _vec: {
        type: inner_type_name
      }
    }
  }
end

def build_primitive(primitive)
  {
    name: primitive
  }
end

def build_composite(type, types, result)
  composite_type_name = build_type_name(type['path'], type['params'], types, result)

  fields = type['def']['composite']['fields']
  composite = helper_build_composite(fields, types, result)
  {
    name: composite_type_name,
    def: composite
  }
end

def helper_build_composite(fields, types, result)
  return { _tuple: [] } if fields.empty?

  field_names = []
  type_ids = []
  fields.each do |field|
    field_names << field['name']
    type_ids << field['type']
  end
  type_names = type_ids.map do |id|
    get_type(id, types, result)[:name]
  end

  if field_names.include?(nil)
    return {
      _tuple: type_names
    }
  end

  {
    _struct: [field_names.map(&:to_sym), type_names].transpose.to_h
  }
end

# {
#   id => {
#     name: '',
#     def: {
#       _enum: {
#         PreRuntime: { _tuple: ["ConsensusEngineId", "Vec<U8>"] },
#         Normal: { _tuple: [] }
#         ...
#       }
#     }
#   },
# }
def build_variant(type, types, result)
  variant_type_name = build_type_name(type['path'], type['params'], types, result)

  variants = type['def']['variant']['variants']
  {
    name: variant_type_name,
    def: {
      _enum: variants.map do |item|
               [item['name'].to_sym, helper_build_composite(item['fields'], types, result)]
             end.to_h
    }
  }
end

def build_tuple(type_def, types, result)
  type_names = type_def.map do |id|
    get_type(id, types, result)[:name]
  end
  {
    name: "(#{type_names.join(', ')})",
    def: {
      _tuple: type_names
    }
  }
end

def build_compact(type_def, types, result)
  inner_type_name = get_type(type_def['type'], types, result)[:name]
  {
    name: "Compact<#{inner_type_name}>",
    def: {
      _compact: inner_type_name
    }
  }
end

# type_ids.each do |id|
# end
# p build_type(189, types, nil)

result = {
  types: {},
  name_id_map: {}
}
# 0, 3, 7, 10, 11, 12, 16
# p get_type(0, types, result)
#
# puts '----------------------------'

# pallet_collective::pallet::Event<T, I>: 3
# sp_runtime::bounded::bounded_vec::BoundedVec<U8, S>: 5
# pallet_referenda::pallet::Event<T, I>: 2
# result.each_pair do |id, type|
#   if type[:name].start_with? 'pallet_referenda::pallet::Event<T, I>'
#     puts type
#   end
# end

# names = result.values.map do |type|
#   type[:name]
# end
# names.tally.each_pair do |key, value|
#   if value > 1
#     puts "#{key}: #{value}"
#   end
# end

# result[:types].each_pair do |id, type|
#   puts "#{id}: #{type}"
#   puts '----------------------------'
# end
# puts '----------------------------'
# result[:name_id_map].each_pair do |name, id|
#   puts "#{name}: #{id}"
# end

def build_all_types(types)
  result = {
    types: {},
    name_id_map: {}
  }
  types.keys.sort.each do |id|
    get_type(id, types, result)
  end

  result
end

# kasama
all = build_all_types(types)
puts '----------------------------'
p all
