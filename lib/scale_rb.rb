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

require 'type_enforcer'

require 'scale_rb/types'
require 'scale_rb/portable_registry'
require 'scale_rb/codec'

require 'scale_rb/metadata/metadata'

require 'hasher'
require 'storage_helper'

require 'address'

# clients
require 'client/http_client'
require 'client/ws_client'
