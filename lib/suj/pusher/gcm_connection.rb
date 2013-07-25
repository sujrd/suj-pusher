require "em-http"

module Suj
  module Pusher
    class GCMConnection
      include Suj::Pusher::Logger

      GATEWAY = "https://android.googleapis.com/gcm/send"

      def initialize(pool, options = {})
        super
        @pool = pool
        @options = options
        @api_key = options[:api_key]
        @headers =  {
          'Content-Type' => 'application/json',
          'Authorization' => @api_key
        }
      end

      def deliver(msg)
        body = MultiJson.dump({
          registration_ids: msg[:gcm_ids],
          data: msg[:data]
        })

        http = EventMachine::HttpRequest.new(GCM_GATEWAY).post( head: @headers, body: body )

        http.errback do
          error "GCM network error"
          @pool.remove_connection(@api_key)
        end
        http.callback do
          if http.response_header.status != 200
            error "GCM push error #{http.response_header.status}"
            error http.response
          else
            info "GCM push notification send"
            info http.response
          end
          @pool.remove_connection(@api_key)
        end
      end
    end
  end
end
