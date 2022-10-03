# frozen_string_literal: true

module MetadataV14
  class << self
    def build_registry(metadata)
      types = metadata._get(:lookup)._get(:types)
      types.map { |type| [type._get(:id), type._get(:type)] }.to_h
    end

    def get_storage_item(pallet_name, item_name, metadata)
      pallet =
        metadata._get(:pallets).find do |p|
          p._get(:name) == pallet_name
        end

      pallet._get(:storage)._get(:items).find do |item|
        item._get(:name) == item_name
      end
    end
  end
end
