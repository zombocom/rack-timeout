require "logger"
require_relative "core"

class Rack::Timeout::StateChangeLoggingObserver
  STATE_LOG_LEVEL = { :expired   => :error,
                      :ready     => :info,
                      :active    => :debug,
                      :timed_out => :error,
                      :completed => :info,
                    }

  ENV_RACK_LOGGER = 'rack.logger'.freeze
  ENV_RACK_ERRORS = 'rack.errors'.freeze

  # returns the Proc to be used as the observer callback block
  def callback
    method(:log_state_change)
  end

  SIMPLE_FORMATTER = ->(severity, timestamp, progname, msg) { "#{msg} at=#{severity.downcase}\n" }
  def self.mk_logger(device, level = ::Logger::INFO)
    ::Logger.new(device).tap do |logger|
      logger.level     = level
      logger.formatter = SIMPLE_FORMATTER
    end
  end


  attr_writer :logger

  private

  def logger(env = nil)
    @logger ||
      (defined?(::Rails) && ::Rails.logger) ||
      (env && !env[ENV_RACK_LOGGER].is_a?(::Rack::NullLogger) && env[ENV_RACK_LOGGER]) ||
      (env && env[ENV_RACK_ERRORS] && rack_errors_logger(env))      ||
      fallback_logger
  end

  def rack_errors_logger(env)
    @rack_errors_logger ||= self.class.mk_logger(env[ENV_RACK_ERRORS])
  end

  def fallback_logger
    @fallback_logger ||= self.class.mk_logger($stderr)
  end

  # generates the actual log string
  LOG_ID = ' id='.freeze
  LOG_WAIT = ' wait='.freeze
  LOG_TIMEOUT = ' timeout='.freeze
  LOG_SERVICE = ' service='.freeze
  LOG_STATE = ' state='.freeze
  def log_state_change(env)
    info = env[::Rack::Timeout::ENV_INFO_KEY]
    level = STATE_LOG_LEVEL[info.state]
    logger(env).send(level) do
      s  = "source=rack-timeout"
      s << LOG_ID      << info.id           if info.id
      s << LOG_WAIT    << info.ms(:wait)    if info.wait
      s << LOG_TIMEOUT << info.ms(:timeout) if info.timeout
      s << LOG_SERVICE << info.ms(:service) if info.service
      s << LOG_STATE   << info.state.to_s   if info.state
      s
    end
  end

end
