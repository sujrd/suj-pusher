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
        EM.run do

          EM.add_periodic_timer(FEEDBACK_TIME) do
            info "Starting APN feedback service"
            pool.feedback
          end

          Fiber.new {
            loop
          }.resume
        end
      end

      def stop
        pool.close
        redis.close

        if ! pool.pending_connections?
          EM.stop
          info "Stopped daemon process"
        else
          info "Waiting for pending connections"
          EM.add_periodic_timer(5) {
            if ! pool.pending_connections?
              EM.stop
              info "Stopped daemon process"
            end
          }
        end
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
        begin
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
            f.resume(nil)
          end
        rescue EventMachine::Hiredis::Error => e
          info e
        rescue => ex
          error ex
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
