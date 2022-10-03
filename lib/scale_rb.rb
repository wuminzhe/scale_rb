# frozen_string_literal: true

require 'scale_rb/version'
require 'logger'

# scale codec
require 'monkey_patching'
require 'codec'
require 'portable_codec'

# metadata types, decoding and helpers
require 'metadata'
require 'metadata_v14'

require 'hasher'
require 'storage_helper'

# client
require 'client/rpc'
require 'client/client'

# get registry from config
require 'registry'

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
