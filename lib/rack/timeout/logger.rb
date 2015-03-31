require 'logger'

class Rack::Timeout
  class StageChangeLoggingObserver
    STATE_LOG_LEVEL = { :expired   => :error,
                        :ready     => :info,
                        :active    => :debug,
                        :timed_out => :error,
                        :completed => :info,
                      }

    # creates a logger and registers for state change notifications in Rack::Timeout
    def self.register!(logger = nil)
      new.register!(logger)
    end

    # registers for state change notifications in Rack::Timeout (or other explicit target (potentially useful for testing))
    def register!(logger = nil, target = ::Rack::Timeout)
      @logger = logger
      target.register_state_change_observer(:logger, &method(:log_state_change))
    end

    SIMPLE_FORMATTER = ->(severity, timestamp, progname, msg) { "#{msg} at=#{severity.downcase}\n" }
    def self.mk_logger(device, level = ::Logger::INFO)
      ::Logger.new(device).tap do |logger|
        logger.level     = level
        logger.formatter = SIMPLE_FORMATTER
      end
    end

    class << self
      attr_accessor :logger
    end
    def logger(env = nil)
      self.class.logger ||
        (defined?(::Rails) && Rails.logger) ||
        (env && !env['rack.logger'].is_a?(::Rack::NullLogger) && env['rack.logger']) ||
        (env && env['rack.errors'] && self.class.mk_logger(env['rack.errors']))      ||
        (@fallback_logger ||= self.class.mk_logger($stderr))
    end

    # generates the actual log string
    def log_state_change(env)
      info = env[ENV_INFO_KEY]
      level = STATE_LOG_LEVEL[info.state]
      logger(env).send(level) do
        s  = 'source=rack-timeout'
        s << ' id='      << info.id           if info.id
        s << ' wait='    << info.ms(:wait)    if info.wait
        s << ' timeout=' << info.ms(:timeout) if info.timeout
        s << ' service=' << info.ms(:service) if info.service
        s << ' state='   << info.state.to_s   if info.state
        s
      end
    end

  end
end
