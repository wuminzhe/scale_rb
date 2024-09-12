# frozen_string_literal: true

require 'scale_rb/version'
require 'console'

require 'utils'

# scale codec
require 'types'
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

module ScaleRb
  class << self
    attr_accessor :logger

    def debug(key, value)
      logger.debug "#{key.rjust(15)}: #{value}"
    end
  end
end

ScaleRb.logger = Console
