Rack::Timeout
=============

Abort requests that are taking too long; a Timeout::Error will be raised.


Usage
-----

### Rails 3 app or Rails 2.3 app with Ruby 1.9 and Bundler

    # Gemfile
    gem "rack-timeout"

### Rails 3 app or Rails 2.3 app with Ruby 1.8 and Bundler

    # Gemfile
    gem "SystemTimer", :require => "system_timer", :platforms => :ruby_18
    gem "rack-timeout"


### Rails 2.3 app without Bundler

    # config/environment.rb
    config.gem "SystemTimer", :lib => "system_timer" if RUBY_VERSION < "1.9"
    config.gem "rack-timeout"


### Sinatra and other Rack apps

    # config.ru
    require "rack/timeout"
    use Rack::Timeout           # call as early as possible so rack-timeout runs before other middlewares.
    Rack::Timeout.timeout = 10  # this line is optional. if omitted, default is 15 seconds.

### Setting a custom timeout for Rails apps

    # config/initializers/timeout.rb
    Rack::Timeout.timeout = 10  # seconds


### Here be dragons

SystemTimer/timeout rely on threads. If your app or any of the libraries it depends on is not thread-safe,
you may run into issues using rack-timeout.

Concurrent web servers such as [Unicorn][] and [Puma][] should work fine with rack-timeout.

[Unicorn]: http://unicorn.bogomips.org/
[Puma]: http://puma.io/

#### A note about testing timeouts in Rails apps

If you're trying to test that a `Timeout::Error` is being raised in your Rails application, please note that
it's **not possible in functional tests**. You *can*, however, test `assert_raises Rack::Timeout::Error`
in integration tests.

There are more details about general rack middleware testing with Rails in this [@pablobm's answer on Stack Overflow][pablobm].

[pablobm]: http://stackoverflow.com/a/8681208/13989

---
Copyright © 2010 Caio Chassot, released under the MIT license  
<http://github.com/kch/rack-timeout>
