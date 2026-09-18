### Sentry

Because rack-timeout may raise at any point in the codepath of a timed-out request, the stack traces for similar requests may differ, causing Sentry to create separate issues for each timeout.

The recommended practice is to configure a custom [fingerprint][sentry-fingerprinting] in your `before_send` hook, grouping timeouts by the transaction (controller#action) instead of by stack trace. Prepending the route to the exception message also gives each issue a readable, route-led title.

[sentry-fingerprinting]: https://docs.sentry.io/platforms/ruby/usage/sdk-fingerprinting/

Example:

```ruby
Sentry.init do |config|
  config.before_send = lambda do |event, hint|
    exception = hint[:exception]
    timeout = exception.is_a?(Rack::Timeout::RequestTimeoutException) ||
              exception.is_a?(Rack::Timeout::Error)
    if timeout && event.transaction.present?
      event.fingerprint = [exception.class.name, event.transaction]
      timeout_exception = event.exception.values.last
      timeout_exception.value = "#{event.transaction} — #{timeout_exception.value}"
    end
    event
  end
end
```

This groups timeouts by route and titles each issue `Rack::Timeout::RequestTimeoutException: controller#action — Request ran for longer than 15000ms` — the route leads (the Sentry analogue of the Rollbar `title` recipe) while rack-timeout's original wait/timeout detail is preserved rather than discarded.

`RequestTimeoutException` is raised into the application thread; if it bubbles past your middleware it is re-raised as `RequestTimeoutError` (see [doc/exceptions](exceptions.md)). Matching `RequestTimeoutException` and the `Rack::Timeout::Error` base (which covers `RequestTimeoutError` and `RequestExpiryError`) means timeouts group by route regardless of where Sentry's capture middleware sits in the stack. The `event.transaction.present?` guard leaves timeouts raised before controller dispatch (no transaction) on Sentry's default grouping, rather than blanking the title.
