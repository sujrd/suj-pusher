require 'thread'
require 'socket'
require 'pathname'
require 'openssl'
require 'net/http/persistent'
require 'em-hiredis'
require "multi_json"
require 'fileutils'

module Suj
  module Pusher
    class Daemon
      include Suj::Pusher::Logger

      def self.start
        Suj::Pusher.logger.info("Starting daemon process")
        self.new.tap do |daemon|
          daemon.start
        end
      end

      def self.stop
        if ! self.running?
          Suj::Pusher.logger.info "Daemon is not running"
          exit 1
        end
        Process.kill "TERM", self.pid
      end

      def self.status
        if self.running?
          $stderr.puts "Daemon is running with pid #{self.pid}"
          exit 0
        else
          $stderr.puts "Daemon is not running"
          exit 1
        end
      end

      def start
        if Daemon.running?
          warn "Daemon seems to be running already with pid #{pid}"
          return
        end
        Daemon.daemonize if ! Suj::Pusher.config.foreground
        write_pid_file
        EM.run do
          Signal.trap('INT') { stop }
          Signal.trap('TERM') { stop }
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
        FileUtils.rm_f(Suj::Pusher.config.pid_file)
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

      def self.pid_file
        Suj::Pusher.config.pid_file
      end

      def self.pid
        if File.exists?(pid_file)
          pid = File.read(pid_file).to_i
        end
        Suj::Pusher.logger.info("Daemon pid #{pid}")
        return pid
      end

      def self.running?
        return false if ! Daemon.pid
        begin
          Process.kill 0, Daemon.pid
          return true
        rescue Errno::ESRCH
          return false
        end
      end

      def self.daemonize
        Process.daemon(true, true)
        Suj::Pusher.logger.info("Daemonizing process #{Process.pid}")
      end

      def write_pid_file
        File.open(Suj::Pusher.config.pid_file, 'w') do |f|
          f << Process.pid
        end
      end

    end
  end
end
