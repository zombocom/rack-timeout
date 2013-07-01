# encoding: utf-8
require 'securerandom'

module Rack
  class Timeout
    class Error < RuntimeError;        end
    class RequestExpiryError  < Error; end
    class RequestTimeoutError < Error; end

    RequestDetails  = Struct.new(:id, :age, :timeout, :duration, :state)
    ENV_INFO_KEY    = 'rack-timeout.info'
    VALID_STATES    = [:ready, :active, :expired, :timed_out, :completed]
    MAX_REQUEST_AGE = 30 # seconds
    @timeout        = 15 # seconds
    class << self
      attr_accessor :timeout
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      info          = env[ENV_INFO_KEY] ||= RequestDetails.new
      info.id     ||= env['HTTP_HEROKU_REQUEST_ID'] || env['HTTP_X_REQUEST_ID'] || SecureRandom.hex
      request_start = env['HTTP_X_REQUEST_START'] # unix timestamp in ms
      request_start = Time.at(request_start.to_f / 1000) if request_start
      info.age      = Time.now - request_start           if request_start
      time_left     = MAX_REQUEST_AGE - info.age         if info.age
      info.timeout  = [self.class.timeout, time_left].compact.select { |n| n >= 0 }.min

      if time_left && time_left <= 0
        Rack::Timeout._set_state! env, :expired
        raise RequestExpiryError, "Request older than #{MAX_REQUEST_AGE} seconds."
      end

      Rack::Timeout._set_state! env, :ready
      ready_time = Time.now

      begin
        app_thread     = Thread.current
        timeout_thread = Thread.start do
          loop do
            info.duration = Time.now - ready_time
            sleep_seconds = [1, info.timeout - info.duration].min
            break if sleep_seconds <= 0
            Rack::Timeout._set_state! env, :active
            sleep(sleep_seconds)
          end
          Rack::Timeout._set_state! env, :timed_out
          app_thread.raise(RequestTimeoutError, "Request ran for longer than #{info.timeout} seconds.")
        end
        response = @app.call(env)
      ensure
        timeout_thread.kill
        timeout_thread.join
      end

      info.duration = Time.now - ready_time
      Rack::Timeout._set_state! env, :completed
      response
    end

    # used internally
    def self._set_state!(env, state)
      raise "Invalid state: #{state.inspect}" unless VALID_STATES.include? state
      info = env[ENV_INFO_KEY]
      info.state = state
      notify_state_change_observers(env)
    end


    ### state change notification-related methods

    OBSERVER_CALLBACK_METHOD_NAME = :rack_timeout_request_did_change_state_in
    @state_change_observers       = {}

    # Registers an object or a block to be called back when a request changes state in rack-timeout.
    #
    # `id` is anything that uniquely identifies this particular callback, mostly so it may be removed via `unregister_state_change_observer`.
    #
    # The second parameter can be either an object that responds to `rack_timeout_request_did_change_state_in(env)` or a block. The object and the block cannot be both specified at the same time.
    #
    # Example calls:
    #     Rack::Timeout.register_state_change_observer(:foo_reporter, FooStateReporter.new)
    #     Rack::Timeout.register_state_change_observer(:bar) { |env| do_bar_things(env) }
    def self.register_state_change_observer(id, object = nil, &callback)
      raise RuntimeError,  "An observer with the id #{id.inspect} is already set." if @state_change_observers.key? id
      raise ArgumentError, "Pass either a callback object or a block; never both." unless [object, callback].compact.length == 1
      raise RuntimeError,  "Object must respond to rack_timeout_request_did_change_state_in" if object && !object.respond_to?(OBSERVER_CALLBACK_METHOD_NAME)
      callback.singleton_class.send :alias_method, OBSERVER_CALLBACK_METHOD_NAME, :call if callback
      @state_change_observers[id] = object || callback
    end

    # Removes the observer with the given id
    def self.unregister_state_change_observer(id)
      @state_change_observers.delete id
    end


    private

    # Sends out the notifications. Called internally at the end of `set_state!`
    def self.notify_state_change_observers(env)
      @state_change_observers.values.each { |observer| observer.send(OBSERVER_CALLBACK_METHOD_NAME, env) }
    end

  end
end
