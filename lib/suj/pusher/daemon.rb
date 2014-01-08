require 'thread'
require 'socket'
require 'pathname'
require 'openssl'
require 'em-hiredis'
require "multi_json"
require 'fileutils'
require 'fiber'

module Suj
  module Pusher
    class Daemon
      include Suj::Pusher::Logger

      FEEDBACK_TIME = 43200  # 12H

      def start
        info "Starting pusher daemon"
        info " subsribe to push messages from #{redis_url} namespace #{redis_namespace}"
        @last_feedback = Time.now
        @last_sandbox_feedback = Time.now
        EM.run do
          Fiber.new {
            loop
          }.resume
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

      def loop
        msg = get_msg
        return next_tick { loop } if msg.nil?
        conn = get_connection(msg)
        return next_tick { loop } if conn.nil?
        conn.deliver(msg)
        next_tick { loop }
      end

      def next_tick(&blk)
        EM.next_tick { Fiber.new { blk.call }.resume }
      end

      def msg_queue
        @msg_queue ||= "#{redis_namespace}:#{MSG_QUEUE}"
      end

      def get_msg
        f = Fiber.current
        defer = redis.brpop msg_queue, 0
        defer.callback do |_, msg|
          info "Received message"
          begin
            data = Hash.symbolize_keys(MultiJson.load(msg))
            f.resume(data)
          rescue MultiJson::LoadError
            warn("Message has bad json format, discarding")
            f.resume(nil)
          rescue => e
            error(e)
            f.resume(nil)
          end
        end
        defer.errback do |e|
          error e
          f.resume(nil)
        end
        return Fiber.yield
      end

      def get_connection(options)
        info "Get connection"
        begin
          return pool.get_connection(options)
        rescue ConnectionPool::UnknownConnection
          error "Could not find connection"
          return nil
        end
      end

      # def wait_msg
      #   defer = redis.brpop "#{redis_namespace}:#{MSG_QUEUE}", 0
      #   defer.callback do |_, msg|
      #     begin
      #       info "RECEIVED MESSAGE"
      #       data = Hash.symbolize_keys(MultiJson.load(msg))
      #       info "GET CONNECTION"
      #       conn = pool.get_connection(data)
      #       conn.deliver(data)
      #       info "SENT MESSAGE"
      #       retrieve_feedback(data)
      #     rescue MultiJson::LoadError
      #       warn("Received invalid json data, discarding msg")
      #     rescue ConnectionPool::UnknownConnection
      #       warn("Could not determine connetion type for message")
      #     rescue => e
      #       error("Error sending notification : #{e}")
      #       error e.backtrace
      #     end
      #     EM.next_tick { wait_msg }
      #   end
      #   defer.errback do |e|
      #     error e
      #     EM.next_tick { wait_msg }
      #   end
      # end

      def retrieve_feedback(msg)
        if msg.has_key?(:cert)
          if msg.has_key?(:development) && msg[:development]
            feedback_sandbox_connection(msg)
          else
            feedback_connection(msg)
          end
        end
      end

      def feedback_connection(msg)
        return Time.now - @last_feedback < FEEDBACK_TIME
        info "Get feedback information"
        conn = pool.feedback_connection(msg)
        @last_feedback = Time.now
      end

      def feedback_sandbox_connection(msg)
        return if Time.now - @last_sandbox_feedback < FEEDBACK_TIME
        info "Get feedback sandbox information"
        conn = pool.feedback_sandbox_connection(msg)
        @last_sandbox_feedback = Time.now
      end

      def redis_url
        @redis_url ||= "redis://#{Suj::Pusher.config.redis_host}:#{Suj::Pusher.config.redis_port}/#{Suj::Pusher.config.redis_db}"
      end

      def redis_namespace
        Suj::Pusher.config.redis_namespace
      end

      def redis
        return @redis if ! @redis.nil?

        @redis = EM::Hiredis.connect(redis_url)

        @redis.on(:connected) { info "REDIS - Connected to Redis server #{redis_url}" }

        @redis.on(:closed) do
          info "REDIS - Closed connection to Redis server"
          @redis = nil
        end

        @redis.on(:failed) do
          info "REDIS - redis connection FAILED"
          @redis = nil
        end

        @redis.on(:reconnected) { info "REDIS - Reconnected to Redis server" }

        @redis.on(:disconnected) do
          info "REDIS - Disconnected from Redis server"
          @redis = nil
        end

        @redis.on(:reconnect_failed) do
          info "REDIS - Reconnection attempt to Redis server FAILED"
          @redis = nil
        end

        return @redis
      end

      # def get_message
      #   @redis_connection ||= EM::Hiredis.connect(redis_url)
      # end

      def pool
        @pool ||= Suj::Pusher::ConnectionPool.new(self)
      end

    end
  end
end
