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
      APN_PORT = 2195
      FEEDBACK_PORT = 2196

      class UnknownConnection < StandardError; end

      def initialize(daemon)
        @pool = {}
        @daemon = daemon
        @mutex = Mutex.new
        @invalid_tokens = {}
        @processing_ids = {}
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

      def remove_connection(key)
        @mutex.synchronize {
          info "Removing connection #{key}"
          info "Connection not found" unless @pool.delete(key)
        }
      end

      def invalidate_token(conn, token)
        @invalid_tokens[conn] ||= {}
        @invalid_tokens[conn][token] = Time.now.to_s
      end

      def valid_token?(conn, token)
        return true if ! @invalid_tokens[conn]
        return false if @invalid_tokens[conn].has_key?(token)
        return true
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
        cert = Digest::SHA1.hexdigest("FEEDBACK" + options[:cert])
        info "APN Feedback connection #{cert}"
        @mutex.synchronize do
          @pool[cert] ||= EM.connect(FEEDBACK_GATEWAY, FEEDBACK_PORT, APNFeedbackConnection, self, options)
        end
      end

      def feedback_sandbox_connection(options = {})
        cert = Digest::SHA1.hexdigest("FEEDBACK" + options[:cert])
        info "APN Sandbox Feedback connection #{cert}"
        @mutex.synchronize do
          @pool[cert] ||= EM.connect(FEEDBACK_SANDBOX, FEEDBACK_PORT, APNFeedbackConnection, self, options)
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

      def apn_connection(options = {})
        cert = Digest::SHA1.hexdigest options[:cert]
        info "APN connection #{cert}"
        @mutex.synchronize do
          @pool[cert] ||= EM.connect(APN_GATEWAY, APN_PORT, APNConnection, self, options)
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
