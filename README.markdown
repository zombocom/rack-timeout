Rack::Timeout
=============

Abort requests that are taking too long; a `Rack::Timeout::Error` will be raised.


Usage
-----

Setup for current versions of Rails, Rack, Ruby, and Bundler. See the Compatibility section at the
end for legacy versions.

### Rails apps

    # Gemfile
    gem "rack-timeout"

That's all that's required if you want to use the default timeout of 15s. To use a custom timeout,
create an initializer file:

    # config/initializers/timeout.rb
    Rack::Timeout.timeout = 10  # seconds

### Sinatra and other Rack apps

    # config.ru
    require "rack-timeout"
    use Rack::Timeout           # Call as early as possible so rack-timeout runs before other middleware.
    Rack::Timeout.timeout = 10  # This line is optional. If omitted, timeout defaults to 15 seconds.


Heroku Niceties
---------------

*   Normally, Rack::Timeout always times out a request using the `Rack::Timeout.timeout` setting.
    Heroku offers the [`X-Request-Start`][X-Request-Start] HTTP header, which is a timestamp
    indicating the time the request first enters the routing infrastructure.

    If the `X-Request-Start` HTTP header is present, Rack::Timeout will take the age of the request
    into consideration when determining the timeout to use. If a request is older than 30 seconds,
    it's dropped immediately. Otherwise, the timeout is the number of seconds left to 30 seconds,
    or the value of `Rack::Timeout.timeout`, whichever is shorter.

    So, if a request has been sitting in the queue for 25s, and `Rack::Timeout.timeout` is set to
    10s, the timeout used will be 5s, because `30 − 25 = 5`, and `5 < 10`.

    The reasoning for this behavior is that the Heroku router drops requests if no response is
    received within 30s, so it makes no sense for the application to process a request it'll never
    be able to respond to.

    The 30s maximum age is set in in `Rack::Timeout::MAX_REQUEST_AGE`, and should generally not be
    altered.

*   With every line logged, Rack::Timeout includes a request ID. Generally it'll generate its own
    ID, but before that, it'll look for the `Heroku-Request-ID` header. If present, this is the ID
    that'll get logged.

    `Heroku-Request-ID` is not present by default on Heroku apps, but can be enabled through the
    [http-request-id labs feature][http-request-id]. It's recommended to enable http-request-id as
    it allows one to correlate Rack::Timeout events with the Heroku router's events. There are no
    downsides to enabling http-request-id.

[X-Request-Start]: https://devcenter.heroku.com/articles/http-routing#heroku-headers
[http-request-id]: https://devcenter.heroku.com/articles/http-request-id

Both these features are strictly reliant on the presence of the HTTP headers and make no effort to
determine if the app is actually running on Heroku.


Request Lifetime
----------------

Throughout a request's lifetime, Rack::Timeout keeps details about the request in
`env[Rack::Timeout::ENV_INFO_KEY]`, or, more explicitly, `env["rack-timeout.info"]`.

The value of that entry is an instance of `Rack::Timeout::RequestDetails`, which is a `Struct`
containing the following fields:

*   `id`: a unique ID per request. Either `Heroku-Request-ID` or a random ID generated internally.

*   `age`: time in seconds since `X-Request-Start` when the request is first seen by Rack::Timeout.
    Only set if `X-Request-Start` is present.

*   `timeout`: timeout to be used, in seconds. Generally `Rack::Timeout.timeout`, unless
    `X-Request-Start` is present. See discussion above under the Heroku Niceties section.

*   `duration`: set after a request completes (or times out). The time in seconds it took.

*   `state`: the possible states are:

    *   `expired`: the request is considered too old and is skipped entirely. This happens when
        `X-Request-Start` is present and older than 30s. When this happens, a
        `Rack::Timeout::RequestExpiryError` exception is raised.

    *   `ready`: this is the initial state a request is in, before it's passed down the middleware
        chain. After that, it'll either end up as `timed_out` or `completed`.

    *   `timed_out`: the request had run for longer than the determined timeout and was aborted. A
        `Rack::Timeout::RequestTimeoutError` error is raised in the application when this occurs.

    *   `completed`: the request completed in time and Rack::Timeout is done with it. This does not
        mean the request completed *successfully*. Rack::Timeout does not concern itself with that.


Errors
------

Rack::Timeout can raise two types of exceptions. Both descend from `Rack::Timeout::Error`, which
itself descends from `RuntimeError`. They are:

*   `Rack::Timeout::RequestTimeoutError`: this is raised when a request has run for longer than the
    specified timeout. This is raised in the application thread, as per the `::Timeout.timeout`
    semantics, and can generally be caught within the application.

*   `Rack::Timeout::RequestExpiryError`: this is raised when a request is skipped for being too old
    (see the X-Request-Start bit under the Heroku Niceties section). This cannot generally be
    rescued from in a Rails controller action as it happens before the request has a chance to reach
    Rails.

    This shouldn't be any different for other frameworks, unless you have something above
    Rack::Timeout in the middleware stack, which you generally shouldn't.

You shouldn't generally care about rescuing from these errors. Instead, you can subscribe for state
change notifications with observers.


Observers
---------

Observers are objects or blocks that are notified about state changes during a request lifetime.

You can register an observer easily with a block:

    Rack::Timeout.register_state_change_observer(:a_unique_name) { |env| do_things env }

or by passing an object that responds to `rack_timeout_request_did_change_state_in(env)`:

    class MyObserver
      def rack_timeout_request_did_change_state_in(env)
        # ... do stuff ...
      end
    end

    Rack::Timeout.register_state_change_observer(:another_name, MyObserver.new)

This is how logging is implemented, too. See `Rack::Timeout::StateChangeLogger`.

You can remove an observer with `unregister_state_change_observer`:

    Rack::Timeout.unregister_state_change_observer(:a_unique_name)

Custom observers might be used to store statistics on request length, timeouts, etc., and
potentially do performance tuning on the fly.


Logging
-------

Rack::Timeout logs a line every time there's a change in state in a request's lifetime.

Changes into `timed_out` and `expired` are logged at the `ERROR` level, everything else is `INFO`.

The default log level for Rack::Timeout is `INFO`, but can be affected via:

*   Unix environment variables. First `RACK_TIMEOUT_LOG_LEVEL` is checked, then `LOG_LEVEL`. Their
    value must be name of a predefined constant in ruby's `Logger` class, e.g. `INFO` or `DEBUG`.
    Case is not significant.

*   By setting `Rack::Timeout.logger.level` directly, e.g.:

        Rack::Timeout.logger.level = ::Logger::DEBUG

Logging is enabled by default if Rack::Timeout is loaded via the `rack-timeout` file (recommended),
but can be removed by unregistering its observer:

    Rack::Timeout.unregister_state_change_observer(:logger)

Each log line is a set of `key=value` pairs, containing the entries from the
`env["rack-timeout.info"]` struct that are not `nil`. See the Request Lifetime section above for a
description of each field. Note that while the values for `age`, `timeout`, and `duration` are
stored internally as seconds, they are logged as milliseconds for readability.

A sample log excerpt might look like:

    source=rack-timeout id=13793c age=369ms timeout=10000ms state=ready at=info
    source=rack-timeout id=13793c age=369ms timeout=10000ms duration=15ms state=completed at=info
    source=rack-timeout id=ea7bd3 age=371ms timeout=10000ms state=timed_out at=error

(IDs shortened for readability.)


Compatibility
-------------

This version of Rack::Timeout is compatible with Ruby 1.9.1 and up, and, for Rails apps, Rails 3.x
and up.

For applications running Ruby 1.8.x and/or Rails 2.x, use [version 0.0.4][v0.0.4].

[v0.0.4]: https://github.com/kch/rack-timeout/tree/v0.0.4


Here Be Dragons
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
