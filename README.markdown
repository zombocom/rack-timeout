Rack::Timeout
=============

Abort requests that are taking too long.


Usage
-----

### Rails 3 app or Rails 2.3 app with Bundler

    # Gemfile
    gem "SystemTimer", :require => "system_timer" if RUBY_VERSION < "1.9"
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


---
Copyright © 2010 Caio Chassot, released under the MIT license
<http://github.com/kch/rack-timeout>
