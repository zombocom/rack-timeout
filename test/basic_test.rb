require "test_helper"

class BasicTest < RackTimeoutTest
  def test_ok
    self.settings = { service_timeout: 1 }
    get "/"
    assert last_response.ok?
  end

  def test_timeout
    self.settings = { service_timeout: 1 }
    assert_raises(Rack::Timeout::RequestTimeoutError) do
      get "/sleep"
    end
  end

  def test_timeout_with_proc
    self.settings = { service_timeout: proc { 5 } }
    assert_raises(Rack::Timeout::RequestTimeoutError) do
      get "/sleep"
    end
  end

  def test_wait_timeout_with_proc
    request_path_timeouts = { request_path: 1, web_timeout: 15 }

    self.settings = { service_timeout: ->(request_path_timeouts) { request_path_timeouts[:request_path] || 5 }, wait_timeout: ->(request_path_timeouts) { request_path_timeouts[:web_timeout] || 1 } }
    assert_raises(Rack::Timeout::RequestExpiryError) do
      get "/", "", 'HTTP_X_REQUEST_START' => time_in_msec(Time.now - 100)
    end
  end

  def test_wait_timeout
    self.settings = { service_timeout: 1, wait_timeout: 15 }
    assert_raises(Rack::Timeout::RequestExpiryError) do
      get "/", "", 'HTTP_X_REQUEST_START' => time_in_msec(Time.now - 100)
    end
  end
end
