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
        info " subsribe to push messages from #{redis_url} namespace #{redis_namespace}"
        EM.run do
          wait_msg do |msg|
            begin
              info "RECEIVED MESSAGE"
              data = Hash.symbolize_keys(MultiJson.load(msg))
              send_notification(data)
              info "SENT MESSAGE"
              retrieve_feedback(data)
              info "FINISHED FEEDBACK RETRIEVAL"
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
        redis.on(:connected) { info "REDIS - Connected to Redis server #{redis_url}" }
        redis.on(:closed) { info "REDIS - Closed connection to Redis server" }
        redis.on(:failed) { info "REDIS - redis connection FAILED" }
        redis.on(:reconnected) { info "REDIS - Reconnected to Redis server" }
        redis.on(:disconnected) { info "REDIS - Disconnected from Redis server" }
        redis.on(:reconnect_failed) { info "REDIS - Reconnection attempt to Redis server FAILED" }
        # EM.add_periodic_timer(30) { redis.publish Suj::Pusher::QUEUE, "ECHO" }
        redis.pubsub.subscribe("#{redis_namespace}:#{Suj::Pusher::QUEUE}") do |msg|
          if msg == "ECHO"
            info "REDIS - ECHO Received"
          elsif msg == "PUSH_MSG"
            info "REDIS - PUSH_MSG Received"
            get_message.callback do |message|
              if message
                yield message
              else
                info "REDIS - PUSH_MSG Queue was empty"
              end
            end
          else
            yield msg
          end
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
        elsif msg.has_key?(:secret) && msg.has_key?(:sid)
          #wns push notification
          send_wns_notification(msg)
        elsif  msg.has_key?(:wpnotificationclass)
          #send wpns push notification
          send_wpns_notification(msg)
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

      def send_wns_notification(msg)
        info "Sending WNS notification via connection #{Digest::SHA1.hexdigest(msg[:secret])}"
        conn = pool.wns_connection(msg)
        conn.deliver(msg)
      end

      def send_wpns_notification(msg)
        info "Sending WPNS notification via connection #{Digest::SHA1.hexdigest(msg[:secret])}"
        conn = pool.wpns_connection(msg)
        conn.deliver(msg)
      end



      def redis_url
        @redis_url ||= "redis://#{Suj::Pusher.config.redis_host}:#{Suj::Pusher.config.redis_port}/#{Suj::Pusher.config.redis_db}"
      end

      def redis_namespace
        Suj::Pusher.config.redis_namespace
      end

      def redis
        @redis ||= EM::Hiredis.connect(redis_url)
      end

      def get_message
        @redis_connection ||= EM::Hiredis.connect(redis_url)
        @redis_connection.rpop "#{redis_namespace}:#{MSG_QUEUE}"
      end

      def pool
        @pool ||= Suj::Pusher::ConnectionPool.new(self)
      end

    end
  end
end
