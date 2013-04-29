# encoding: utf-8
require 'timeout'
require 'securerandom'

module Rack
  class Timeout
    class Error < RuntimeError;        end
    class RequestExpiryError  < Error; end
    class RequestTimeoutError < Error; end

    RequestDetails       = Struct.new(:id, :age, :timeout, :duration, :state)
    ENV_INFO_KEY         = 'rack-timeout.info'
    FRAMEWORK_ERROR_KEYS = %w(sinatra.error rack.exception)
    FINAL_STATES         = [:expired, :timed_out, :completed]
    ACCEPTABLE_STATES    = [:ready] + FINAL_STATES
    MAX_REQUEST_AGE      = 30 # seconds

    @timeout = 15
    class << self
      attr_accessor :timeout
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      info          = env[ENV_INFO_KEY] ||= RequestDetails.new
      info.id     ||= env['HTTP_HEROKU_REQUEST_ID'] || SecureRandom.hex
      request_start = env['HTTP_X_REQUEST_START'] # unix timestamp in ms
      request_start = Time.at(request_start.to_i / 1000) if request_start
      info.age      = Time.now - request_start           if request_start
      time_left     = MAX_REQUEST_AGE - info.age         if info.age
      info.timeout  = [self.class.timeout, time_left].compact.select { |n| n >= 0 }.min

      if time_left && time_left <= 0
        Rack::Timeout.set_state! env, :expired
        raise RequestExpiryError
      end

      Rack::Timeout.set_state! env, :ready
      ::Timeout.timeout(info.timeout, RequestTimeoutError) do
        ready_time    = Time.now
        response      = Rack::Timeout.perform_block_tracking_timeout_to_env(env) { @app.call(env) }
        info.duration = Time.now - ready_time
        Rack::Timeout.set_state! env, :completed
        response
      end
    end

    def self.perform_block_tracking_timeout_to_env(env)
      yield
    rescue RequestTimeoutError
      timed_out = true
      raise
    ensure
      timed_out ||= env.values_at(*FRAMEWORK_ERROR_KEYS).any? { |e| e.is_a? RequestTimeoutError }
      set_state! env, :timed_out if timed_out
    end

    def self.set_state!(env, state)
      raise "Invalid state: #{state.inspect}" unless ACCEPTABLE_STATES.include? state
      info = env[ENV_INFO_KEY]
      return if FINAL_STATES.include? info.state
      info.state = state
      log_state_change(info)
    end

    def self.log_state_change(info)
      ms = ->(s) { '%.fms' % (s * 1000) }
      s  = 'source=rack-timeout'
      s << ' id='       << info.id           if info.id
      s << ' age='      << ms[info.age]      if info.age
      s << ' timeout='  << ms[info.timeout]  if info.timeout
      s << ' duration=' << ms[info.duration] if info.duration
      s << ' state='    << info.state.to_s   if info.state
      s << "\n"

      $stderr << s
    end

    class TimeoutTracker
      def initialize(app)
        @app = app
      end

      def call(env)
        Rack::Timeout.perform_block_tracking_timeout_to_env(env) { @app.call(env) }
      end
    end

  end
end
