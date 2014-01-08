require "eventmachine"
require "iobuffer"
require "base64"
require 'suj/pusher/monkey/vash'

module Suj
  module Pusher
    class APNConnection < EM::Connection
      include Suj::Pusher::Logger

      @@last_id = 0

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
        10 => "Shutdown",
        255 => "Unknown error"
      }

      def initialize(pool, options = {})
        super
        @disconnected = true
        @pool = pool
        @options = options
        @processing_ids = Vash.new
        @cert_key = Digest::SHA1.hexdigest(@options[:cert])
        @cert_file = File.join(Suj::Pusher.config.certs_path, @cert_key)
        @buffer = IO::Buffer.new
        self.comm_inactivity_timeout = 60          # Close after 60 sec of inactivity

        File.open(@cert_file, "w") do |f|
          f.write @options[:cert]
        end

        @ssl_options = {
          private_key_file: @cert_file,
          cert_chain_file: @cert_file,
          verify_peer: false
        }
      end

      def options
        @options
      end

      def disconnected?
        @disconnected
      end

      def deliver(data)
        begin
          @notifications = []
          data[:apn_ids].each do |apn_id|
            if ! @pool.valid_token?(@cert_key, apn_id)
              warn "Skipping invalid #{apn_id} APN id"
              next
            end
            notification = Suj::Pusher::ApnNotification.new(data.merge({token: apn_id, id: @@last_id}))
            @processing_ids[@@last_id.to_s] = apn_id
            @@last_id += 1
            @notifications << notification
          end

          @processing_ids.cleanup!
          info "Processing list size #{@processing_ids.size}"

          if @notifications.empty?
            warn "No valid tokens, skip message"
            return
          end

          if disconnected?
            warn "Connection not ready yet, queue notifications for later"
            return
          end

          info "APN delivering data"
          send_data(@notifications.join)
          @notifications = nil
          info "APN delivered data"
        rescue Suj::Pusher::ApnNotification::PayloadTooLarge => e
          error "APN notification payload too large."
          debug @notifications.join.inspect
        rescue => ex
          error "APN notification error : #{ex}"
          error ex.backtrace
        end
      end

      def post_init
        info "APN Connection init "
        start_tls(@ssl_options)
      end

      # Receives error data from APN servers. Each error is 6 bytes long
      # and contains:
      #
      #   cmd    -> 1 byte unsigned integer that is always 8
      #   status -> 1 byte unsigned integer that indicates the error
      #             See ERRORS array for a list
      #   id     -> 4 byte message ID set when the message was sent
      def receive_data(data)
        @buffer << data
        while @buffer.size >= 6
          res = @buffer.read(6)
          cmd, status, id = data.unpack("CCN")
          if cmd != 8
            error "APN push response command differs from 8"
          elsif status == 8
            token = @processing_ids[id.to_s]
            @pool.invalidate_token(@cert_key, token)
            warn "APN invalid (id: #{id}) token #{token}"
          elsif status != 0
            error "APN push error received: #{ERRORS[status]} for id #{id}"
          end
        end
      end

      def connection_completed
        info "APN Connection established..."
        @disconnected = false

        return if @notifications.nil? || @notifications.empty?

        info "EST - APN delivering data"
        send_data(@notifications.join)
        @notifications = nil
        info "EST - APN delivered data"
      end

      def unbind
        info "APN Connection closed..."
        @disconnected = true
        @pool.remove_connection(@cert_key)
      end
    end
  end
end
