require 'uri'
require 'net/http'
require 'json'

# composite => struct
# array => fixed length array
# primitive => u8, ...
# sequence => vec
# variant => enum
# compact
# tuple
# bitSequence => bitvec

# url = 'https://raw.githubusercontent.com/polkadot-js/api/master/packages/types-support/src/metadata/v14/substrate-types.json'
# url = 'https://raw.githubusercontent.com/polkadot-js/api/master/packages/types-support/src/metadata/v14/kusama-types.json'
# uri = URI.parse(url)
# response = Net::HTTP.get_response(uri)
# puts response.body
# json = JSON.parse response.body

# result =
#   # json.select { |type| type['type']['def'].keys[0] == 'primitive' }
#   types.map { |type| type['type']['def'].keys[0] }
#        .uniq

types = JSON.parse(File.open('./substrate-types.json').read)
types = types.map { |type| [type['id'], type['type']] }.to_h
# type_names = types.values.map do |type|
#   type['path'].last unless type['path'].empty?
# end
# puts type_names.length
# puts type_names.reject(&:nil?).length
# puts type_names.reject(&:nil?).uniq.length
# puts type_names.reject(&:nil?).tally
type_ids = types.keys.sort.reverse

def build_type(id, types, _result)
  # id = 12# type_ids[0]
  type = types[id]
  type_name = build_type_name(type['path'], type['params'])
  type_n = build_composite(type['def']['composite']['fields']) if type['def'].key?('composite')
  [ 
    type_name, type_n
  ]
end

def build_composite(fields)
  if fields.empty?
    { _tuple: [] }
  else
    names = []
    type_names = []
    fields.each do |field|
      names << field['name']
      type_names << field['typeName']
    end

    if names.include?(nil)
      {
        _tuple: type_names
      }
    else
      {
        _struct: [names.map(&:to_sym), type_names].transpose.to_h
      }
    end
  end
end

# {
#   "id": 189,
#   "type": {
#     "path": [],
#     "params": [],
#     "def": {
#       "array": {
#         "len": 2,
#         "type": 184
#       }
#     },
#     "docs": []
#   }
# }
#
#
def build_array(len, inner_type_id, types)
  build_type(inner_type_id)
end


# {
#   _tuple: [
#     '',
#     ''
#   ]
# }
def build_type_name(path, params)
  return if path.empty?

  name = path.last

  return name if params.empty?

  "#{name}<#{params.reduce([]) { |out, param| out << param['name'] }.join(', ')}>"
end

type_ids.each do |id|
  p build_type(id, types, nil)
end

# puts build_type_name(%w[
#                        sp_runtime
#                        generic
#                        digest
#                        DigestItem
#                      ], [
#                        {
#                          "name": 'E',
#                          "type": 18
#                        },
#                        {
#                          "name": 'T',
#                          "type": 10
#                        }
#                      ])

# def build_type(id, types)
#   type = types[id]
#   len = type['def']['array']['len'] if type['def'].key?('array')
# end
#
# types =
# [
#   {
#     'SpCoreCryptoAccountId32': {
#       composite: {
#         fields: [
#           {
#             name: null,
#             type: 1,
#             type_name: '[u8; 32]',
#             docs: []
#           }
#         ]
#       }
#     }
#   }
# ]
#
# def build_array(_len, inner_type_id)
#   [build_type(inner_type_id)]
# end
