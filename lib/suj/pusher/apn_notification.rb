module Suj
  module Pusher
    class ApnNotification
      MAX_SIZE = 256

      class InvalidToken < StandardError; end
      class PayloadTooLarge < StandardError; end

      def initialize(options = {})
        @token = options[:token]
        @options = options
        raise InvalidToken if @token.nil? || (@token.length != 64)
        raise PayloadTooLarge if data.size > MAX_SIZE
      end

      def payload
        @payload ||= MultiJson.dump(@options[:aps] || {})
      end

      def data
        @data ||= encode_data
      end

      private

      def encode_data
        identifier = 0
        expiry = 0
        size = [payload].pack("a*").size
        data_array = [1, identifier, expiry, 32, @token, size, payload]
        Suj::Pusher.logger.info("PAYLOAD: #{data_array}")
        data_array.pack("cNNnH*na*")
      end

    end
  end
end
