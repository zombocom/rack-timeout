require RUBY_VERSION < '1.9' && RUBY_PLATFORM != "java" ? 'system_timer' : 'timeout'
SystemTimer ||= Timeout

module Rack
  class Timeout
    @timeout = 15
    @exclude_uris = []
    @include_uris = []

    class << self
      attr_accessor :timeout, :exclude_uris, :include_uris
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      request_uri = env['REQUEST_URI'] || env['PATH_INFO']
      if excluded_uri?(request_uri)
        @app.call(env)
      elsif included_uri?(request_uri)
        SystemTimer.timeout(self.class.timeout, ::Timeout::Error) { @app.call(env) }
      end
    end

    private

    def excluded_uri?(request_uri)
      uri_in?(self.class.exclude_uris, request_uri)
    end

    def included_uri?(request_uri)
      self.class.include_uris.empty? || uri_in?(self.class.include_uris, request_uri)
    end

    def uri_in?(uris, request_uri)
      uris.any? {|uri| /#{uri}/ =~ request_uri}
    end
  end
end
