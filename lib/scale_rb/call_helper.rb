# frozen_string_literal: true

module ScaleRb
  module CallHelper
    # callbytes's structure is: pallet_index + call_index + argsbytes
    #
    # callbytes examples:
    #   "0x0901"._to_bytes
    #   "0x05000a1287977578f888bdc1c7627781af1cc000e6ab1300004c31b8d9a798"._to_bytes
    def self.decode_call(callbytes, metadata)
      pallet_index = callbytes[0]
      pallet = Metadata.get_module_by_index(pallet_index, metadata)

      # Remove the pallet_index
      # The callbytes we used below should not contain the pallet index.
      # This is because the pallet index is not part of the call type.
      # Its structure is: call_index + call_args
      callbytes_without_pallet_index = callbytes[1..]
      calls_type_id = pallet._get(:calls, :type)
      decoded = Codec.decode(
        calls_type_id,
        callbytes_without_pallet_index,
        Metadata.build_registry(metadata)
      )&.first

      {
        pallet_name: pallet._get(:name),
        call_name: decoded.is_a?(::Hash) ? decoded.keys.first.to_s : decoded.to_s,
        call: decoded
      }
    end

    # call examples:
    #   {:pallet_name=>"Deposit", :call_name=>"claim", :call=>:claim]}
    #   {:pallet_name=>"Balances", :call_name=>"transfer", :call=>{:transfer=>{:dest=>[10, 18, 135, 151, 117, 120, 248, 136, 189, 193, 199, 98, 119, 129, 175, 28, 192, 0, 230, 171], :value=>11000000000000000000}}]}
    def self.encode_call(call, metadata)
      calls_type_id = Metadata.get_calls_type_id(call[:pallet_name], metadata)
      pallet_index = Metadata.get_module(call[:pallet_name], metadata)._get(:index)
      [pallet_index] + Codec.encode(calls_type_id, call[:call], Metadata.build_registry(metadata))
    end
  end
end
