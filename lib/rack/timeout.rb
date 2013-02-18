require RUBY_VERSION < '1.9' && RUBY_PLATFORM != "java" ? 'system_timer' : 'timeout'
SystemTimer ||= Timeout

module Rack
  class Timeout
    @timeout = 15
    @excludes = []
    class << self
      attr_accessor :timeout, :excludes
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      if self.class.excludes.any? {|exclude_uri| /#{exclude_uri}/ =~ env['REQUEST_URI']}
        @app.call(env)
      else
        SystemTimer.timeout(self.class.timeout, ::Timeout::Error) { @app.call(env) }
      end
    end

  end
end
