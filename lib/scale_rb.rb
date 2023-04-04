# frozen_string_literal: true

require 'scale_rb/version'
require 'logger'

# scale codec
require 'monkey_patching'
require 'codec'
require 'portable_codec'

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

# client
require 'client/rpc_request_builder'
require 'client/http_client'
require 'client/abstract_ws_client'

# get registry from config
require 'registry'

require 'address'

module ScaleRb
  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout)
      @logger.level = Logger::INFO
      @logger
    end

    def debug(key, value)
      logger.debug "#{key.rjust(15)}: #{value}"
    end
  end
end
