require 'thread'
require 'socket'
require 'pathname'
require 'openssl'
require 'em-hiredis'
require "multi_json"
require 'fileutils'

module Suj
  module Pusher
    class Daemon
      include Suj::Pusher::Logger

      def start
        info "Starting pusher daemon"
        EM.run do
          wait_msg do |msg|
            begin
              data = Hash.symbolize_keys(MultiJson.load(msg))
              send_notification(data)
            rescue MultiJson::LoadError
              warn("Received invalid json data, discarding msg")
            end
          end
        end
      end

      def stop
        info "Stopping daemon process"
        begin
          EM.stop
        rescue
        end
        info "Stopped daemon process"
      end

      private

      def wait_msg
        redis.pubsub.subscribe(Suj::Pusher::QUEUE) do |msg|
          yield msg
        end
      end

      def send_notification(msg)
        if msg.has_key?(:cert)
          if msg.has_key?(:development) && msg[:development]
            send_apn_sandbox_notification(msg)
          else
            send_apn_notification(msg)
          end
        elsif msg.has_key?(:api_key)
          send_gcm_notification(msg)
        else
          warn "Could not determine push notification service."
        end
      end

      def send_apn_notification(msg)
        info "Sending APN notification via connection #{Digest::SHA1.hexdigest(msg[:cert])}"
        conn = pool.apn_connection(msg)
        msg[:apn_ids].each do |apn_id|
          conn.deliver(msg.merge({token: apn_id}))
        end
      end

      def send_apn_sandbox_notification(msg)
        info "Sending APN sandbox notification via connection #{Digest::SHA1.hexdigest(msg[:cert])}"
        conn = pool.apn_sandbox_connection(msg)
        msg[:apn_ids].each do |apn_id|
          conn.deliver(msg.merge({token: apn_id}))
        end
      end

      def send_gcm_notification(msg)
        info "Sending GCM notification via connection #{msg[:api_key]}"
        conn = pool.gcm_connection(msg)
        conn.deliver(msg)
      end

      def redis
        @redis || EM::Hiredis.connect(Suj::Pusher.config.redis)
      end

      def pool
        @pool ||= Suj::Pusher::ConnectionPool.new(self)
      end

    end
  end
end
