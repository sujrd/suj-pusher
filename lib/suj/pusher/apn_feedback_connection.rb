require "eventmachine"
require "iobuffer"

require "base64"
module Suj
  module Pusher
    class APNFeedbackConnection < EM::Connection
      include Suj::Pusher::Logger

      def initialize(pool, options = {})
        super
        @disconnected = true
        @options = options
        @pool = pool
        @cert_key = Digest::SHA1.hexdigest(@options[:cert])
        @cert_file = File.join(Suj::Pusher.config.certs_path, @cert_key)
        @buffer = IO::Buffer.new
        self.comm_inactivity_timeout = 10          # Close after 10 sec of inactivity
        File.open(@cert_file, "w") do |f|
          f.write @options[:cert]
        end
        @ssl_options = {
          private_key_file: @cert_file,
          cert_chain_file: @cert_file,
          verify_peer: false
        }
        info "APN feedback #{@cert_key}: Creating"
      end

      def disconnected?
        @disconnected
      end

      def post_init
        info "APN feedback #{@cert_key}: Connection init "
        start_tls(@ssl_options)
      end

      # Receive feedback data from APN servers.
      #
      # The format is:
      #
      #   timestamp -> 4 byte bigendian
      #   len       -> 2 byte token length
      #   token     -> 32 bytes token
      def receive_data(data)
        @buffer << data

        while @buffer.size >= 38
          timestamp, size = @buffer.read(6).unpack("Nn")
          token = @buffer.read(size)
          info "APN feedback #{@cert_key}: TIMESTAMP: #{timestamp} SIZE: #{size} TOKEN: #{token}"
          @pool.invalidate_token(@cert_key, token)
        end
      end

      def connection_completed
        info "APN feedback #{@cert_key}: Connection established..."
        @disconnected = false
      end

      def unbind
        info "APN feedback #{@cert_key}: Connection closed..."
        @disconnected = true
        @pool.remove_feedback_connection(@cert_key)
      end
    end
  end
end
