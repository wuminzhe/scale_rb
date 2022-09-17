require 'json'

# types = JSON.parse(File.open('./substrate-types.json').read)
types = JSON.parse(File.open('./kusama-types.json').read)
types = types.map { |type| [type['id'], type['type']] }.to_h

def print_names_with_more_than_1_occurrences(types)
  types
    .values
    .map { |type| build_type_name(type['path'], type['params']) }
    .reject(&:nil?)
    .tally
    .reject { |_k, v| v == 1 }
    .each_pair { |k, v| puts "#{k}: #{v}" }
end

# print_names_with_more_than_1_occurrences(types)

def print_types_of_nil(types)
  types.each do |_id, type|
    puts type['def'] if type['path'].empty?
  end
end

# print_types_of_nil(types)

# {
#   types: {
#     id => {
#       name: '',
#       def: _ # optional
#     }
#   },
#   id_name_map: {
#     id => name
#   },
#   name_id_map: {
#     name => id
#   }
# }
def build_type_names(types, result)
  types.each_key do |id|
    _get_name(id, result[:id_name_map], types)
  end
end

def _get_name(id, id_name_map, types)
  return id_name_map[id] unless id_name_map[id].nil?

  path = types[id]['path']
  params = types[id]['params']
  type_def = types[id]['def']
  if type_def.key?('primitive')
    _get_primitive_name(id, type_def, id_name_map)
  elsif type_def.key?('array')
    _get_array_name(id, type_def, id_name_map, types)
  elsif type_def.key?('sequence')
    _get_sequence_name(id, type_def, id_name_map, types)
  elsif type_def.key?('tuple')
    _get_tuple_name(id, type_def, id_name_map, types)
  elsif type_def.key?('compact')
    _get_compact_name(id, type_def, id_name_map, types)
  elsif type_def.key?('bitSequence')
    _get_bit_sequence_name(id, type_def, id_name_map, types)
  else
    _get_other_name(id, path, params, id_name_map, types)
  end
end

def _get_other_name(id, path, params, id_name_map, types)
  return if path.empty?

  name = path.join('::')

  if params.empty?
    id_name_map[id] = name
    return id_name_map[id]
  end

  param_names_str = params.map do |param|
    param_type_id = param['type']
    if param_type_id.nil?
      param['name']
    else
      _get_name(param_type_id, id_name_map, types)
    end
  end.join(', ')

  id_name_map[id] = "#{name}<#{param_names_str}>"
  id_name_map[id]
end

def _get_primitive_name(id, type_def, id_name_map)
  id_name_map[id] = type_def['primitive']
  id_name_map[id]
end

def _get_bit_sequence_name(id, type_def, id_name_map, types)
  inner_store_type_id = type_def['bitSequence']['bitStoreType']
  inner_store_type_name = id_name_map[inner_store_type_id]
  inner_store_type_name = _get_name(inner_store_type_id, id_name_map, types) if inner_store_type_name.nil?
  # return if inner_type_name.nil?

  inner_order_type_id = type_def['bitSequence']['bitOrderType']
  inner_order_type_name = id_name_map[inner_order_type_id]
  inner_order_type_name = _get_name(inner_order_type_id, id_name_map, types) if inner_order_type_name.nil?
  # return if inner_type_name.nil?

  id_name_map[id] = "BitVec<#{inner_store_type_name}, #{inner_order_type_name}>"
  id_name_map[id]
end

def _get_compact_name(id, type_def, id_name_map, types)
  inner_type_id = type_def['compact']['type']
  inner_type_name = id_name_map[inner_type_id]
  inner_type_name = _get_name(inner_type_id, id_name_map, types) if inner_type_name.nil?
  return if inner_type_name.nil?

  id_name_map[id] = "Compact<#{inner_type_name}>"
  id_name_map[id]
end

def _get_tuple_name(id, type_def, id_name_map, types)
  inner_type_ids = type_def['tuple']
  inner_type_names =
    inner_type_ids.map do |inner_type_id|
      inner_type_name = id_name_map[inner_type_id]
      inner_type_name = _get_name(inner_type_id, id_name_map, types) if inner_type_name.nil?
      inner_type_name
    end

  id_name_map[id] = "(#{inner_type_names.join(', ')})"
  id_name_map[id]
end

def _get_sequence_name(id, type_def, id_name_map, types)
  inner_type_id = type_def['sequence']['type']
  inner_type_name = id_name_map[inner_type_id]
  inner_type_name = _get_name(inner_type_id, id_name_map, types) if inner_type_name.nil?
  return if inner_type_name.nil?

  id_name_map[id] = "Vec<#{inner_type_name}>"
  id_name_map[id]
end

def _get_array_name(id, type_def, id_name_map, types)
  len = type_def['array']['len']
  inner_type_id = type_def['array']['type']
  inner_type_name = id_name_map[inner_type_id]
  inner_type_name = _get_name(inner_type_id, id_name_map, types) if inner_type_name.nil?
  return if inner_type_name.nil?

  id_name_map[id] = "[#{inner_type_name}; #{len}]"
  id_name_map[id]
end

result = {
  id_name_map: {}
}
build_type_names(types, result)
# result[:id_name_map]
#   .values
#   .tally
#   .reject { |_k, v| v == 1 }
#   .each_pair { |k, v| puts "#{k}: #{v}" }
result[:id_name_map].each do |id, name|
  puts "#{id}: #{name}" # if name.nil?
end
