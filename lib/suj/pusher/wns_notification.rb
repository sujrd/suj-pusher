module Suj
  module Pusher
    class WnsNotification
      include Suj::Pusher::Logger


      def initialize(options = {})
	@options = options
      end

      def payload
        @payload ||= MultiJson.dump(@options[:data] || {})
      end

      def data
        @data ||= encode_data
      end

      private

      def get_expiry
        if @ttl.to_i == 0
          return 0
        else
          return Time.now.to_i + @ttl.to_i
        end
      end

      def encode_data
      Base64.encode64(payload)
      end
    end
  end
end
