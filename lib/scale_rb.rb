# frozen_string_literal: true

require 'scale_rb/version'
require 'console'

module ScaleRb
  class << self
    attr_accessor :logger

    def debug(key, value)
      logger.debug "#{key.rjust(15)}: #{value}"
    end
  end
end

ScaleRb.logger = Console

require 'utils'

# scale codec
require 'scale_rb/types'
require 'type_enforcer'
# require 'types/old_registry/type_exp'
# require 'types/build_types_from_registry'
require 'scale_rb/portable_registry'

require 'codec'

require 'scale_rb/codec'

# metadata types, decoding and helpers
require 'metadata/metadata_v9'
require 'metadata/metadata_v10'
require 'metadata/metadata_v11'
require 'metadata/metadata_v12'
require 'metadata/metadata_v13'
require 'metadata/metadata_v14'
require 'metadata/metadata'

require 'hasher'
require 'storage_helper'

# get registry from config
require 'registry'

require 'address'

# clients
require 'client/http_client'
require 'client/ws_client'
