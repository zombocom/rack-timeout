Rack::Timeout
=============

Abort requests with Timeout::Error when they are taking too long.

This fork differs from kch's in that it adds Timeout::Error as the default error class when calling timeout.
Passing in the error class allows Rails to use rescue_from Timeout::Error in Rails controllers instead of
rescue_from Exception.


Usage
-----

### Rails 3 app or Rails 2.3 app with Bundler

    # Gemfile
    gem "SystemTimer", :require => "system_timer", :platforms => :ruby_18
    gem "rack-timeout"


### Rails 2.3 app without Bundler

    # config/environment.rb
    config.gem "SystemTimer", :require => "system_timer" if RUBY_VERSION < "1.9"
    config.gem "rack-timeout"


### Sinatra and other Rack apps

    # config.ru
    require 'rack/timeout'
    use Rack::Timeout
    Rack::Timeout.timeout = 10  # this line is optional. if omitted, default is 30 seconds.


### Setting a custom timeout for Rails apps:

    # config/initializers/timeout.rb
    Rack::Timeout.timeout = 10  # seconds


### Here be dragons

SystemTimer/timeout rely on threads. If your app or any of the libraries it depends on is
not thread-safe, you may run into issues using rack-timeout.


---
Copyright © 2010 Caio Chassot, released under the MIT license
<http://github.com/kch/rack-timeout>
