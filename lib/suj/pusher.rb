require 'suj/pusher/monkey/hash'
require 'suj/pusher/version'
require 'suj/pusher/configuration'
require 'suj/pusher/logger'
require 'suj/pusher/connection_pool'
require 'suj/pusher/apn_connection'
require 'suj/pusher/gcm_connection'
require 'suj/pusher/apn_notification'
require 'suj/pusher/daemon'

require 'logger'

module Suj
  module Pusher

    QUEUE = "suj_pusher_queue"

    def self.logger
      @logger || Suj::Pusher.config.logger
    end

    def self.logger=(logger)
      @logger = logger
    end
  end
end
