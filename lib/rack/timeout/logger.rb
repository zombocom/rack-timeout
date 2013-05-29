require 'logger'

module Rack
  class Timeout

    # convenience method so the current logger can be accessed via Rack::Timeout.logger
    def self.logger
      @state_change_observers[:logger]
    end

    class StateChangeLogger < ::Logger
      SIMPLE_FORMATTER = ->(severity, timestamp, progname, msg) { "#{msg} at=#{severity.downcase}\n" }
      DEFAULT_LEVEL    = INFO
      STATE_LOG_LEVEL  = { ready:     INFO,
                           active:    DEBUG,
                           completed: INFO,
                           expired:   ERROR,
                           timed_out: ERROR,
                         }


      # creates a logger and registers for state change notifications in Rack::Timeout
      def self.register!(*a)
        new(*a).register!
      end

      # registers for state change notifications in Rack::Timeout
      def register!(target = ::Rack::Timeout)
        target.register_state_change_observer(:logger, self)
      end

      def initialize(device = $stderr, *a)
        super(device, *a)
        self.formatter = SIMPLE_FORMATTER
        self.level     = self.class.determine_level
      end

      # callback method from Rack::Timeout state change notifications
      def rack_timeout_request_did_change_state_in(env)
        log_state_change(env[ENV_INFO_KEY])
      end


      private

      # log level is, by precedence, one of: $RACK_TIMEOUT_LOG_LEVEL > $LOG_LEVEL > INFO
      def self.determine_level
        env_log_level = ENV.values_at("RACK_TIMEOUT_LOG_LEVEL", "LOG_LEVEL").compact.map(&:upcase).first
        env_log_level = const_get(env_log_level) if env_log_level && const_defined?(env_log_level)
        env_log_level || DEFAULT_LEVEL
      end

      # helper method used for formatting in #log_state_change
      def ms(s)
        '%.fms' % (s * 1000)
      end

      # generates the actual log string
      def log_state_change(info)
        add(STATE_LOG_LEVEL[info.state]) do
          s  = 'source=rack-timeout'
          s << ' id='       << info.id           if info.id
          s << ' age='      << ms(info.age)      if info.age
          s << ' timeout='  << ms(info.timeout)  if info.timeout
          s << ' duration=' << ms(info.duration) if info.duration
          s << ' state='    << info.state.to_s   if info.state
          s
        end
      end

    end
  end
end
