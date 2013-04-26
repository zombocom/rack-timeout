# encoding: utf-8
require 'timeout'
require 'securerandom'

module Rack
  class Timeout
    class Error < RuntimeError;        end
    class RequestTooOldError  < Error; end
    class RequestAbortedError < Error; end

    RequestData          = Struct.new(:id, :age, :timeout, :duration, :state)
    ENV_INFO_KEY         = 'rack-timeout.info'
    FRAMEWORK_ERROR_KEYS = %w(sinatra.error rack.exception)
    FINAL_STATES         = [:dropped, :aborted, :completed]
    MAX_REQUEST_AGE      = 30 # seconds

    @timeout = 15
    class << self
      attr_accessor :timeout
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      info          = env[ENV_INFO_KEY] ||= RequestData.new
      info.id     ||= env['HTTP_HEROKU_REQUEST_ID'] || SecureRandom.hex
      request_start = env['HTTP_X_REQUEST_START'] # unix timestamp in ms
      request_start = Time.at(request_start.to_i / 1000) if request_start
      info.age      = Time.now - request_start           if request_start
      time_left     = MAX_REQUEST_AGE - info.age         if info.age
      info.timeout  = [self.class.timeout, time_left].compact.select { |n| n >= 0 }.min

      if time_left && time_left <= 0
        Rack::Timeout.set_state_and_log! info, :dropped
        raise RequestTooOldError
      end

      Rack::Timeout.set_state_and_log! info, :ready
      ::Timeout.timeout(info.timeout, RequestAbortedError) do
        ready_time    = Time.now
        response      = Rack::Timeout.perform_reporting_abortion_state_in_env(env) { @app.call(env) }
        info.duration = Time.now - ready_time
        Rack::Timeout.set_state_and_log! info, :completed
        response
      end
    end

    def self.perform_reporting_abortion_state_in_env(env)
      yield
    rescue RequestAbortedError
      set_aborted! env
      raise
    ensure
      set_aborted! env if env.values_at(*FRAMEWORK_ERROR_KEYS).any? { |e| e.is_a? RequestAbortedError }
    end

    def self.set_aborted!(env)
      set_state_and_log!(env[ENV_INFO_KEY], :aborted)
    end

    def self.set_state_and_log!(info, state)
      return if FINAL_STATES.include? info.state
      info.state = state
      ms         = ->(s) { '%.fms' % (s * 1000) }
      s          = 'source=rack-timeout'
      s << ' id='       << info.id           if info.id
      s << ' age='      << ms[info.age]      if info.age
      s << ' timeout='  << ms[info.timeout]  if info.timeout
      s << ' duration=' << ms[info.duration] if info.duration
      s << ' state='    << info.state.to_s   if info.state
      s << "\n"

      $stderr << s
    end

    class AbortionReporter
      def initialize(app)
        @app = app
      end

      def call(env)
        Rack::Timeout.perform_reporting_abortion_state_in_env(env) { @app.call(env) }
      end
    end

  end
end
