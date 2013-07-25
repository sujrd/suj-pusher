require "em-http"

module Suj
  module Pusher
    class GCMConnection
      include Suj::Pusher::Logger

      GATEWAY = "https://android.googleapis.com/gcm/send"

      def initialize(pool, key, options = {})
        @pool = pool
        @options = options
        @key = key
        @headers =  {
          'Content-Type' => 'application/json',
          'Authorization' => "key=#{options[:api_key]}"
        }
      end

      def deliver(msg)

        return if msg[:gcm_ids].empty?

        body = MultiJson.dump({
          registration_ids: msg[:gcm_ids],
          data: msg[:data] || {}
        })


        http = EventMachine::HttpRequest.new(GATEWAY).post( head: @headers, body: body )

        http.errback do
          error "GCM network error"
          @pool.remove_connection(@key)
        end
        http.callback do
          if http.response_header.status != 200
            error "GCM push error #{http.response_header.status}"
            error http.response
          else
            info "GCM push notification send"
            info http.response
          end
          @pool.remove_connection(@key)
        end
      end
    end
  end
end
