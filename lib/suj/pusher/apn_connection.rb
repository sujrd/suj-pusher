require "eventmachine"

require "base64"
module Suj
  module Pusher
    class APNConnection < EM::Connection
      include Suj::Pusher::Logger

      ERRORS = {
        0 => "No errors encountered",
        1 => "Processing error",
        2 => "Missing device token",
        3 => "Missing topic",
        4 => "Missing payload",
        5 => "Invalid token size",
        6 => "Invalid topic size",
        7 => "Invalid payload size",
        8 => "Invalid token",
        255 => "Unknown error"
      }

      def initialize(pool, options = {})
        super
        @disconnected = true
        @pool = pool
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

      def deliver(data)
        begin
          @notification = Suj::Pusher::ApnNotification.new(data)
          if ! disconnected?
            info "APN delivering data"
            send_data(@notification.data)
            @notification = nil
            info "APN delivered data"
          end
        rescue Suj::Pusher::ApnNotification::PayloadTooLarge => e
          error "APN notification payload too large."
          debug @notification.data.inspect
        rescue => ex
          error "APN notification error : #{ex}"
        end
      end

      def post_init
        info "APN Connection init "
        start_tls(@ssl_options)
      end

      def receive_data(data)
        cmd, status, id = data.unpack("ccN")
        if status != 0
          error "APN push error received: #{ERRORS[status]}"
        else
          info "APN push notification sent"
        end
      end

      def connection_completed
        info "APN Connection established..."
        @disconnected = false
        if ! @notification.nil?
          info "APN delivering data"
          send_data(@notification.data)
          @notification = nil
        end
      end

      def unbind
        info "APN Connection closed..."
        @disconnected = true
        FileUtils.rm_f(@cert_file)
        @pool.remove_connection(@cert)
      end
    end
  end
end
