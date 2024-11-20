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

require 'scale_rb/utils'

require 'type_enforcer'

require 'scale_rb/types'
require 'scale_rb/portable_registry'
require 'scale_rb/old_registry'
require 'scale_rb/codec'

require 'scale_rb/metadata/metadata'
require 'scale_rb/runtime_types'

require 'scale_rb/hasher'
require 'scale_rb/storage_helper'
require 'scale_rb/call_helper'

require 'address'

# clients
require 'scale_rb/client/http_client'
require 'scale_rb/client/ws_client'

require 'scale_rb/metadata/types_helper'
