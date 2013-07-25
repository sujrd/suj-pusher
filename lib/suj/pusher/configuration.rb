module Suj
  module Pusher

    def self.config
      @config ||= Suj::Pusher::Configuration.new
    end

    def self.configure
      yield config if block_given?
    end

    CONFIG_ATTRS = [
      :foreground,
      :pid_file,
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

      def workdir=(path)
        if path && !Pathname.new(path).absolute?
          path = File.join("/var/run", path)
        end
        create_workdir(path)
        super(path)
      end

      def foreground=(bool)
        if defined? JRUBY_VERSION
          # The JVM does not support fork().
          super(true)
        else
          super
        end
      end

      def set_defaults
        if defined? JRUBY_VERSION
          # The JVM does not support fork().
          self.foreground = true
        else
          self.foreground = false
        end

        self.workdir = "/tmp/pusher"
        self.redis = "redis://localhost:6379"
      end

      def create_workdir(path)
        self.pid_file = File.join(path, "pusher.pid")
        self.certs_path = File.join(path, "certs")
        FileUtils.mkdir_p(path, mode: 750)
        FileUtils.mkdir_p(self.certs_path, mode: 750)
        self.logger = ::Logger.new(File.join(path, "pusher.log"))
      end
    end
  end
end
