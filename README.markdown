Rack::Timeout
=============

Abort requests that are taking too long; a `Rack::Timeout::Error` will be raised.


Usage
-----

Setup for current versions of Rails, Rack, Ruby, and Bundler. See next section for legacy versions.

### Rails apps

    # Gemfile
    gem "rack-timeout"

That's all that's required if you want to use the default timeout of 15s. To use a custom timeout,
create an initializer file:

    # config/initializers/timeout.rb
    Rack::Timeout.timeout = 10  # seconds

### Sinatra and other Rack apps

    # config.ru
    require "rack/timeout"
    use Rack::Timeout           # Call as early as possible so rack-timeout runs before other middleware.
    Rack::Timeout.timeout = 10  # This line is optional. If omitted, timeout defaults to 15 seconds.


Compatibility
-------------

This version of Rack::Timeout is compatible with Ruby 1.9.1 and up, and, for Rails apps, Rails 3.x
and up.

For applications running Ruby 1.8.x and/or Rails 2.x, use [version 0.0.4][v0.0.4].

[v0.0.4]: https://github.com/kch/rack-timeout/tree/v0.0.4


Here be dragons
---------------

*   Ruby's Timeout rely on threads. If your app or any of the libraries it depends on is not
    thread-safe, you may run into issues using Rack::Timeout.

    Concurrent web servers such as [Unicorn][] and [Puma][] should work fine with Rack::Timeout.

*   If you're trying to test that a `Rack::Timeout::Error` is raised in an action in your Rails
    application, you **must do so in integration tests**. Please note that Rack::Timeout will not
    kick in for functional tests as they bypass the rack middleware stack.

    [More details about testing middleware with Rails here][pablobm].

[Unicorn]: http://unicorn.bogomips.org/
[Puma]:    http://puma.io/
[pablobm]: http://stackoverflow.com/a/8681208/13989

---
Copyright © 2010-2013 Caio Chassot, released under the MIT license  
<http://github.com/kch/rack-timeout>
