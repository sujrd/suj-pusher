require "eventmachine"

require "base64"
module Suj
  module Pusher
    class APNFeedbackConnection < EM::Connection
      include Suj::Pusher::Logger

      def initialize(options = {})
        super
        @disconnected = true
        @options = options
        @cert_key = Digest::SHA1.hexdigest(@options[:cert])
        @cert_file = File.join(Suj::Pusher.config.certs_path, @cert_key)
        File.open(@cert_file, "w") do |f|
          f.write @options[:cert]
        end
        @ssl_options = {
          private_key_file: @cert_file,
          cert_chain_file: @cert_file,
          verify_peer: false
        }
      end

      def disconnected?
        @disconnected
      end

      def post_init
        info "APN Feedback Connection init "
        start_tls(@ssl_options)
      end

      def receive_data(data)
        timestamp, size, token = data.unpack("QnN")
        info "APN Feedback invalid token #{token}"
      end

      def connection_completed
        info "APN Feedback Connection established..."
        @disconnected = false
      end

      def unbind
        info "APN Feedback Connection closed..."
        @disconnected = true
      end
    end
  end
end
