require "base64"
require "thread"
require File.join File.dirname(File.expand_path(__FILE__)), "apn_connection.rb"
require File.join File.dirname(File.expand_path(__FILE__)), "gcm_connection.rb"

module Suj
  module Pusher
    class ConnectionPool
      include Suj::Pusher::Logger

      APN_SANDBOX = "gateway.sandbox.push.apple.com"
      APN_GATEWAY = "gateway.push.apple.com"
      FEEDBACK_SANDBOX = "feedback.sandbox.push.apple.com"
      FEEDBACK_GATEWAY = "feedback.push.apple.com"
      CONNECTION_EXPIRY = 60*60*24*30  # Approx 1 month
      TOKEN_EXPIRY      = 60*60*24*7   # Approx 1 week
      APN_PORT = 2195
      FEEDBACK_PORT = 2196

      class UnknownConnection < StandardError; end

      def initialize(daemon)
        @pool = {}
        @feedback_pool = {}
        @daemon = daemon
        @mutex = Mutex.new
        @feedback_mutex = Mutex.new
        @invalid_tokens = Vash.new
      end

      def get_connection(options = {})
        if options.has_key?(:cert)
          if options.has_key?(:development) && options[:development]
            return apn_sandbox_connection(options)
          else
            return apn_connection(options)
          end
        elsif options.has_key?(:api_key)
          return gcm_connection(options)
        elsif options.has_key?(:secret) && options.has_key?(:sid)
          return wns_connection(options)
        elsif  options.has_key?(:wpnotificationclass)
          return wpns_connection(options)
        end
        raise UnknownConnection
      end

      def get_feedback_connection(options = {})
        if options.has_key?(:cert)
          if options.has_key?(:development) && options[:development]
            return feedback_sandbox_connection(options)
          else
            return feedback_connection(options)
          end
        end
        return nil
      end

      def remove_feedback_connection(key)
        @feedback_mutex.synchronize {
          info "Removing feedback connection #{key}"
          @feedback_pool.delete(key)
        }
      end

      def remove_connection(key)
        @mutex.synchronize {
          info "Removing connection #{key}"
          info "Connection not found" unless @pool.delete(key)
        }
      end

      def invalidate_token(conn, token)
        @invalid_tokens[conn, CONNECTION_EXPIRY] = Vash.new if @invalid_tokens[conn].nil?
        @invalid_tokens[conn][token, TOKEN_EXPIRY] = Time.now.to_s
      end

      def valid_token?(conn, token)
        return true if ! @invalid_tokens[conn]
        return false if @invalid_tokens[conn].has_key?(token)
        return true
      end

      # Method that creates APN feedback connections
      def feedback
        @invalid_tokens.cleanup!
        @invalid_tokens.each { |k,v| v.cleanup! if v }

        @pool.each do |k, conn|
          next if ! conn.is_a?(Suj::Pusher::APNConnection)
          conn = get_feedback_connection(conn.options)
        end
      end

      def close
        @mutex.synchronize {
          @pool.each do |k, conn|
            conn.close_connection_after_writing
          end
        }
        @feedback_mutex.synchronize {
          @feedback_pool.each do |k, conn|
            conn.close_connection
          end
        }
      end

      def pending_connections?
        @pool.size + @feedback_pool.size > 0
      end

      private

      def apn_connection(options = {})
        cert = Digest::SHA1.hexdigest options[:cert]
        info "APN connection #{cert}"
        @mutex.synchronize do
          @pool[cert] ||= EM.connect(APN_GATEWAY, APN_PORT, APNConnection, self, options)
        end
      end

      def apn_sandbox_connection(options = {})
        cert = Digest::SHA1.hexdigest options[:cert]
        info "APN sandbox connection #{cert}"
        @mutex.synchronize do
          @pool[cert] ||= EM.connect(APN_SANDBOX, APN_PORT, APNConnection, self, options)
        end
      end

      def feedback_connection(options = {})
        cert = Digest::SHA1.hexdigest(options[:cert])
        info "Get APN feedback connection #{cert}"
        @feedback_mutex.synchronize do
          @feedback_pool[cert] ||= EM.connect(FEEDBACK_GATEWAY, FEEDBACK_PORT, APNFeedbackConnection, self, options)
        end
      end

      def feedback_sandbox_connection(options = {})
        cert = Digest::SHA1.hexdigest(options[:cert])
        info "Get APN sandbox feedback connection #{cert}"
        @feedback_mutex.synchronize do
          @feedback_pool[cert] ||= EM.connect(FEEDBACK_SANDBOX, FEEDBACK_PORT, APNFeedbackConnection, self, options)
        end
      end

      def gcm_connection(options = {})
        # All GCM connections are unique, even if they are to the same app.
        api_key = "#{options[:api_key]}#{rand * 100}"
        info "GCM connection #{api_key}"
        @mutex.synchronize do
          @pool[api_key] ||= Suj::Pusher::GCMConnection.new(self, api_key, options)
        end
      end

      def wns_connection(options = {})
        cert = Digest::SHA1.hexdigest options[:secret]
        info "WNS connection #{cert}"
        info "WNS Options #{options}"
        @mutex.synchronize do
          @pool[cert] ||= Suj::Pusher::WNSConnection.new(self,options)
        end
      end

      def wpns_connection(options = {})
        cert = Digest::SHA1.hexdigest options[:secret]
        info "WPNS connection #{cert}"
        info "WPNS Options #{options}"
        @mutex.synchronize do
          @pool[cert] ||= Suj::Pusher::WPNSConnection.new(self,options)
        end
      end

    end

  end
end
