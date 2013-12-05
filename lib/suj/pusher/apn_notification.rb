module Suj
  module Pusher
    class ApnNotification
      include Suj::Pusher::Logger
      MAX_SIZE = 256

      class InvalidToken < StandardError; end
      class PayloadTooLarge < StandardError; end

      def initialize(options = {})
        @token = options[:token]
        @ttl = options[:time_to_live] || 0
        @options = options
        raise InvalidToken if @token.nil? || (@token.length != 64)
        raise PayloadTooLarge if data.size > MAX_SIZE
      end

      def payload
        @payload ||= MultiJson.dump(@options[:data] || {})
      end

      def data
        @data ||= encode_data
      end

      def to_s
        data
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
        # identifier = 0
        # expiry = get_expiry
        # size = [payload].pack("a*").size
        # data_array = [1, identifier, expiry, 32, @token, size, payload]
        # info("PAYLOAD: #{data_array}")
        # data_array.pack("cNNnH*na*")
        
        items = [
          [1, 32,               @token ],                           # token
          [2, payload.bytesize, payload ],                          # payload
          [3, 4,                OpenSSL::Random::random_bytes(4) ], # random identifier
          [4, 4,                get_expiry ],                       # expiration date
          [5, 1,                10 ]                                # high priority
        ]

        info("PAYLOAD: #{items}")

        frame_data = 
          items[0].pack("CnH*") +
          items[1].pack("CnA*") +
          items[2].pack("CnA*") +
          items[3].pack("CnN")  +
          items[4].pack("CnC")

        [2,frame_data.bytesize,frame_data].pack("CNA*")
      end
    end
  end
end
