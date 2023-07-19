require 'test_helper'

class EnvSettingsTest < RackTimeoutTest


  def test_zero_wait_timeout
    with_env(RACK_TIMEOUT_WAIT_TIMEOUT: 0) do
      get "/", "", 'HTTP_X_REQUEST_START' => time_in_msec(Time.now - 100)
      assert last_response.ok?
    end
  end

  def test_generic_message
    with_env(RACK_TIMEOUT_GENERIC_MESSAGE: 1) do
      self.settings = { service_timeout: 1 }
      e = assert_raises(Rack::Timeout::RequestTimeoutError) do
        get "/sleep"
      end
      assert_equal 'Request timed out', e.message
    end
  end
  
  if Process.respond_to?(:fork) # This functionality does not work on windows, so we cannot test it there.
    def test_service_timeout
      with_env(RACK_TIMEOUT_SERVICE_TIMEOUT: 1) do
        assert_raises(Rack::Timeout::RequestTimeoutError) do
          get "/sleep"
        end
      end
    end

    def test_term
      with_env(RACK_TIMEOUT_TERM_ON_TIMEOUT: 1) do
        assert_raises(SignalException) do
          get "/sleep"
        end
      end
    end
  else
    def test_service_timeout # Confirm that on Windows we raise an exception when someone attempts to use term on timeout
      with_env(RACK_TIMEOUT_TERM_ON_TIMEOUT: 1) do 
        assert_raises(NotImplementedError) do
          get "/"
        end
      end
    end
  end
end
