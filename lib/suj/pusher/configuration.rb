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
      :redis
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
        self.redis = "redis://localhost:6379"
        self.logger = ::Logger.new(STDOUT)
      end

    end
  end
end
