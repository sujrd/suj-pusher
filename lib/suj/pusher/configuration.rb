module Suj
  module Pusher

    def self.config
      @config ||= Suj::Pusher::Configuration.new
    end

    def self.configure
      yield config if block_given?
    end

    CONFIG_ATTRS = [
      :certs_path,
      :workdir,
      :logger,
      :redis_host,
      :redis_port,
      :redis_db,
      :redis_namespace
    ]

    class Configuration < Struct.new(*CONFIG_ATTRS)

      def initialize
        super
        set_defaults
      end

      def update(other)
        CONFIG_ATTRS.each do |attr|
          other_value = other.send(attr)
          send("#{attr}=", other_value) unless other_value.nil?
        end
      end

      def set_defaults
        self.redis_host = "localhost"
        self.redis_port = 6379
        self.redis_db = 0
        self.redis_namespace = "pusher"
        self.logger = ::Logger.new(STDOUT)
      end

    end
  end
end
