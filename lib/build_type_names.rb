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
def build_type_names(types, id_name_map = {})
  types.each_key do |id|
    _get_name(id, id_name_map, types)
  end
end

def _get_name(id, id_name_map, types)
  return id_name_map[id] unless id_name_map[id].nil?

  path = types[id]['path']
  params = types[id]['params']
  type_def = types[id]['def']
  name =
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

  id_name_map[id] = name
end

def _get_other_name(_id, path, params, id_name_map, types)
  return if path.empty?

  name = path.join('::')

  return name if params.empty?

  param_names_str = params.map do |param|
    param_type_id = param['type']
    if param_type_id.nil?
      param['name']
    else
      _get_name(param_type_id, id_name_map, types)
    end
  end.join(', ')

  "#{name}<#{param_names_str}>"
end

# def get_type_name(id, name, name_id_map)
#   if name_id_map.key?(name)
#     exist_id = name_id_map[name]
#     if exist_id != id
#       # different type with same name
#       splits = name.split('/')
#       no = splits.length > 1 ? splits.last.to_i + 1 : 1
#       return get_type_name(id, "#{splits[0]}/#{no}", name_id_map)
#     end
#   end
#
#   name
# end

def _get_primitive_name(_id, type_def, _id_name_map)
  type_def['primitive']
end

def _get_bit_sequence_name(_id, type_def, id_name_map, types)
  inner_store_type_id = type_def['bitSequence']['bitStoreType']
  inner_store_type_name = id_name_map[inner_store_type_id]
  inner_store_type_name = _get_name(inner_store_type_id, id_name_map, types) if inner_store_type_name.nil?
  # return if inner_type_name.nil?

  inner_order_type_id = type_def['bitSequence']['bitOrderType']
  inner_order_type_name = id_name_map[inner_order_type_id]
  inner_order_type_name = _get_name(inner_order_type_id, id_name_map, types) if inner_order_type_name.nil?
  # return if inner_type_name.nil?

  "BitVec<#{inner_store_type_name}, #{inner_order_type_name}>"
end

def _get_compact_name(_id, type_def, id_name_map, types)
  inner_type_id = type_def['compact']['type']
  inner_type_name = id_name_map[inner_type_id]
  inner_type_name = _get_name(inner_type_id, id_name_map, types) if inner_type_name.nil?
  return if inner_type_name.nil?

  "Compact<#{inner_type_name}>"
end

def _get_tuple_name(_id, type_def, id_name_map, types)
  inner_type_ids = type_def['tuple']
  inner_type_names =
    inner_type_ids.map do |inner_type_id|
      inner_type_name = id_name_map[inner_type_id]
      inner_type_name = _get_name(inner_type_id, id_name_map, types) if inner_type_name.nil?
      inner_type_name
    end

  "(#{inner_type_names.join(', ')})"
end

def _get_sequence_name(_id, type_def, id_name_map, types)
  inner_type_id = type_def['sequence']['type']
  inner_type_name = id_name_map[inner_type_id]
  inner_type_name = _get_name(inner_type_id, id_name_map, types) if inner_type_name.nil?
  return if inner_type_name.nil?

  "Vec<#{inner_type_name}>"
end

def _get_array_name(_id, type_def, id_name_map, types)
  len = type_def['array']['len']
  inner_type_id = type_def['array']['type']
  inner_type_name = id_name_map[inner_type_id]
  inner_type_name = _get_name(inner_type_id, id_name_map, types) if inner_type_name.nil?
  return if inner_type_name.nil?

  "[#{inner_type_name}; #{len}]"
end
