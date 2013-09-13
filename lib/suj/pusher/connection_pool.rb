require "base64"
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

      def initialize(daemon)
        @pool = {}
        @daemon = daemon
      end

      def apn_connection(options = {})
        cert = Digest::SHA1.hexdigest options[:cert]
        info "APN connection #{cert}"
        @pool[cert] ||= EM.connect(APN_GATEWAY, APN_PORT, APNConnection, self, options)
      end

      def apn_sandbox_connection(options = {})
        cert = Digest::SHA1.hexdigest options[:cert]
        info "APN connection #{cert}"
        @pool[cert] ||= EM.connect(APN_SANDBOX, APN_PORT, APNConnection, self, options)
      end

      def feedback_connection(options = {})
        info "Feedback connection"
        EM.connect(FEEDBACK_GATEWAY, FEEDBACK_PORT, APNFeedbackConnection, options)
      end

      def feedback_sandbox_connection(options = {})
        info "Feedback sandbox connection"
        EM.connect(FEEDBACK_SANDBOX, FEEDBACK_PORT, APNFeedbackConnection, options)
      end

      def gcm_connection(options = {})
        # All GCM connections are unique, even if they are to the same app.
        api_key = "#{options[:api_key]}#{rand * 100}"
        info "GCM connection #{api_key}"
        @pool[api_key] ||= Suj::Pusher::GCMConnection.new(self, api_key, options)
      end

      def remove_connection(key)
        info "Removing connection #{key}"
        info "Connection not found" unless @pool.delete(key)
      end

    end

  end
end
