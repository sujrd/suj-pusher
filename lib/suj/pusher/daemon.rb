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

      FEEDBACK_TIME = 43200  # 12H

      def start
        info "Starting pusher daemon"
        EM.run do
          wait_msg do |msg|
            begin
              data = Hash.symbolize_keys(MultiJson.load(msg))
              send_notification(data)
              retrieve_feedback(data)
            rescue MultiJson::LoadError
              warn("Received invalid json data, discarding msg")
            rescue => e
              error("Error sending notification : #{e}")
              error e.backtrace
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

      def retrieve_feedback(msg)
        if msg.has_key?(:cert)
          if msg.has_key?(:development) && msg[:development]
            feedback_sandbox_connection(msg)
          else
            feedback_connection(msg)
          end
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

      def feedback_connection(msg)
        return if @last_feedback and (Time.now - @last_feedback < FEEDBACK_TIME)
        info "Get feedback information"
        conn = pool.feedback_connection(msg)
        @last_feedback = Time.now
      end

      def feedback_sandbox_connection(msg)
        return if @last_sandbox_feedback and (Time.now - @last_sandbox_feedback < FEEDBACK_TIME)
        info "Get feedback sandbox information"
        conn = pool.feedback_sandbox_connection(msg)
        @last_sandbox_feedback = Time.now
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
