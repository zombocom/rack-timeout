require 'test/unit'
require 'rack/test'
require File.expand_path(File.dirname(__FILE__)) + '/../../lib/rack/timeout'

class TimeoutTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    app = Rack::Builder.new do
      Rack::Timeout.timeout = 1
      use Rack::Timeout
      map '/foo' do
        run Proc.new{[200, {}, "App"]}
      end
      map '/bar' do
        run Proc.new{sleep 2 ; [200, {}, "App"]}
      end
      map '/baz' do
        run Proc.new{sleep 2 ; [200, {}, "App"]}
      end
      map '/qux' do
        run Proc.new{sleep 2 ; [200, {}, "App"]}
      end
    end.to_app
  end

  def test_should_not_timeout_if_request_completes_within_duration
    get "/foo"
    assert last_response.ok?
  end

  def test_should_timeout_if_request_does_not_complete_within_duration
    assert_raises Timeout::Error do
      get "/bar"
    end
  end

  def test_should_timeout_if_uri_is_in_included_list
    Rack::Timeout.include_uris = ['baz']
    assert_raises Timeout::Error do
      get "/baz"
    end
  end

  def test_should_not_timeout_if_uri_is_in_excluded_list
    Rack::Timeout.exclude_uris = ['qux']
    get "/qux"
    assert last_response.ok?
  end
end
