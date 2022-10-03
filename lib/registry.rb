# frozen_string_literal: true

module ScaleRb
  # A `registry` is a ruby Hash object, key is the type name, value is the type definition or mapped type name.
  # A `config` contains the complete versioned type definition for a network.
  # https://github.com/polkadot-js/api/blob/master/packages/types-known/src/spec/polkadot.ts
  def self.build_registry_from_config(config, spec_version)
    version = config[:versioned].find do |item|
      item[:minmax].include?(spec_version)
    end
    config[:shared_types].merge(version.nil? ? {} : version[:types])
  end
end
