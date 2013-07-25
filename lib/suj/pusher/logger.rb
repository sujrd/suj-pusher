module Suj
  module Pusher
    module Logger

      private

      def info(msg); Suj::Pusher.logger.info(msg); end
      def warn(msg); Suj::Pusher.logger.warn(msg); end
      def error(msg); Suj::Pusher.logger.error(msg); end
      def fatal(msg); Suj::Pusher.logger.fatal(msg); end
    end
  end
end
