README is not entirely in sync with this release. E.g. the overtime stuff is not present in this
release. There may be other discrepancies.

Rack::Timeout
=============

Abort requests that are taking too long; a subclass of `Rack::Timeout::Error` is raised.

A generous timeout of 15s is the default. It's recommended to set the timeout as low as
realistically viable for your application.


Usage
-----

The following covers currently supported versions of Rails, Rack, Ruby, and Bundler. See the
Compatibility section at the end for legacy versions.

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
    Heroku makes available the [`X-Request-Start`][X-Request-Start] HTTP header, which is a
    timestamp indicating the time the request first enters the routing infrastructure.

    If the `X-Request-Start` HTTP header is present, Rack::Timeout will take the age of the request
    into consideration when determining the timeout to use. If a request is older than 30 seconds,
    it's dropped immediately. Otherwise, the timeout is the number of seconds left for the request
    to be 30 seconds old, or the value of `Rack::Timeout.timeout`, whichever is shorter.

    So, if a request has been sitting in the queue for 25s, and `Rack::Timeout.timeout` is set to
    10s, the timeout used will be 5s, because `30 − 25 = 5`, and `5 < 10`.

    The reasoning for this behavior is that the Heroku router drops requests if no data is
    transferred within 30s, so it makes no sense for the application to process a request it'll
    never be able to respond to. (This is actually [a bit more involved][heroku-routing].)

    The 30s maximum age is set in `Rack::Timeout::MAX_REQUEST_AGE`, and should generally not be
    altered.

    An exception to this is made for requests that have a non-empty body, e.g. POST, PUT, and PATCH
    requests. X-Request-Start is set when the Heroku router begins receiving the request, but rack
    will generally only see the request after it's been fully received by the application server
    (i.e. thin, unicorn, etc). For short requests such as GET requests, this is irrelevant. But
    with a slow client (say, a mobile app performing a file upload) the request can take a long
    time to be fully received. A request that took longer than 30s to transmit would be dropped
    immediately by Rack::Timeout because it'd be considered too old. The Heroku router, however,
    would not have dropped this request because it would have been transmitting data all along.

    For requests with a body, Rack::Timeout provides additional overtime before expiring them. The
    default overtime is 60s, on top of the 30s `MAX_REQUEST_AGE`. This is user-configurable with
    the `Rack::Timeout.overtime` setting:

        Rack::Timeout.overtime = 10 # seconds over MAX_REQUEST_AGE

*   With every line logged, Rack::Timeout includes a request ID. It'll first look for an ID in the
    `Heroku-Request-ID` header; if not present, it'll then check `X-Request-ID`; and lastly, it'll
    generate its own.

    `Heroku-Request-ID` is not present by default on Heroku apps, but can be enabled through the
    [http-request-id labs feature][http-request-id]. It's recommended to enable http-request-id as
    it allows one to correlate Rack::Timeout events with the Heroku router's events. There are no
    downsides to enabling http-request-id.

[X-Request-Start]: https://devcenter.heroku.com/articles/http-routing#heroku-headers
[heroku-routing]:  https://devcenter.heroku.com/articles/http-routing#timeouts
[http-request-id]: https://devcenter.heroku.com/articles/http-request-id

Both these features are strictly reliant on the presence of the HTTP headers and make no effort to
determine if the app is actually running on Heroku.


Request Lifetime
----------------

Throughout a request's lifetime, Rack::Timeout keeps details about the request in
`env[Rack::Timeout::ENV_INFO_KEY]`, or, more explicitly, `env["rack-timeout.info"]`.

The value of that entry is an instance of `Rack::Timeout::RequestDetails`, which is a `Struct`
containing the following fields:

*   `id`: a unique ID per request. Either `Heroku-Request-ID`, `X-Request-ID`, or a random ID
    generated internally.

*   `age`: time in seconds since `X-Request-Start` when the request is first seen by Rack::Timeout.
    Only set if `X-Request-Start` is present.

*   `timeout`: timeout to be used, in seconds. Generally `Rack::Timeout.timeout`, unless
    `X-Request-Start` is present. See discussion above, under the Heroku Niceties section.

*   `duration`: set after a request completes (or times out). The time in seconds it took. This is
    also updated while a request is still active, around every second, with the time it's taken so
    far.

*   `state`: the possible states are:

    *   `expired`: the request is considered too old and is skipped entirely. This happens when
        `X-Request-Start` is present and older than 30s. When this happens, a
        `Rack::Timeout::RequestExpiryError` exception is raised. See earlier discussion about the
        `Rack::Timeout.overtime` setting, too.

    *   `ready`: this is the initial state a request is in, before it's passed down the middleware
        chain. While it's being processed, it'll move on to `active`, and then on to `timed_out`
        and/or `completed`.

    *   `active`: the request is being actively processed in the application thread. This is
        signaled repeatedly every ~1s until the request completes or times out.

    *   `timed_out`: the request had run for longer than the determined timeout and was aborted. A
        `Rack::Timeout::RequestTimeoutError` error is raised in the application when this occurs.
        If this error gets caught and handled and not re-raised in the app or framework (which will
        generally happen with Rails and Sinatra), this state will not be final, `completed` will be
        set after the framework is done with it.

    *   `completed`: the request completed in time and Rack::Timeout is done with it. This does not
        mean the request completed *successfully*. Rack::Timeout does not concern itself with that.
        As mentioned just above, a timed out request may still end up with a `completed` state.


Errors
------

Rack::Timeout can raise two types of exceptions. Both descend from `Rack::Timeout::Error`, which
itself descends from `RuntimeError`. They are:

*   `Rack::Timeout::RequestTimeoutError`: this is raised when a request has run for longer than the
    specified timeout. This is raised by the rack-timeout timer thread in the application thread,
    at the point in the stack the app happens to be in when the timeout is triggered. This
    exception can generally be caught within the application, but in doing so you're working past
    the timeout. This is ok for quick cleanups but shouldn't be abused as Rack::Timeout will not
    kick in twice for the same request.

*   `Rack::Timeout::RequestExpiryError`: this is raised when a request is skipped for being too old
    (see the X-Request-Start bit under the Heroku Niceties section). This cannot generally be
    rescued from inside a Rails controller action as it happens before the request has a chance to
    reach Rails.

    This shouldn't be any different for other frameworks, unless you have something above
    Rack::Timeout in the middleware stack, which you generally shouldn't.

You shouldn't rescue from these errors for reporting purposes. Instead, you can subscribe for state
change notifications with observers.

If you're trying to test that a `Rack::Timeout::RequestTimeoutError` is raised in an action in your
Rails application, you **must do so in integration tests**. Please note that Rack::Timeout will not
kick in for functional tests as they bypass the rack middleware stack.

[More details about testing middleware with Rails here][pablobm].

[pablobm]: http://stackoverflow.com/a/8681208/13989


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

Changes into `timed_out` and `expired` are logged at the `ERROR` level, most other things are
logged as `INFO`.

Exceptionally, `active` state is logged as `DEBUG`, every ~1s while the request is still active.

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


---
Copyright © 2010-2013 Caio Chassot, released under the MIT license  
<http://github.com/kch/rack-timeout>
