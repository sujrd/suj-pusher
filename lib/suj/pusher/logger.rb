module Suj
  module Pusher
    module Logger

      private

      def info(msg); Suj::Pusher.config.logger.info(msg); end
      def warn(msg); Suj::Pusher.config.logger.warn(msg); end
      def error(msg); Suj::Pusher.config.logger.error(msg); end
      def fatal(msg); Suj::Pusher.config.logger.fatal(msg); end
    end
  end
end
