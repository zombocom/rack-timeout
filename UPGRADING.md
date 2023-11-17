Upgrading
=========

From 0.6.3 or older
-----------------

- Apache's `X-Request-Start` header is now recognized, which if present
  will trigger the default `wait_timeout` behavior (unless you have changed
  those settings or disabled it).

  Please review `wait_timeout` behavior in [doc/settings.md](doc/settings.md#wait-timeout).

  TL;DR -> set `wait_timeout` to `0` or `'false'` to disable it and maintain
  your Apache setup's current behavior.


From 0.4 or older
-----------------

- Removal of the class setters, such as `Rack::Timeout.timeout = 5`, may
  lead to an error when upgrading. To fix this, remove these setters and
  instead use either the [environment variables][config-env],
  `RACK_TIMEOUT_*`, or [insert the middleware manually][config-insert]
  and configure the middleware as desired when inserting.

[config-env]: README.md#configuring
[config-insert]: README.md#rails-apps-manually

- The Rollbar support was removed; a deprecation warning will be emitted
  if you are using this module. The recommendation is to use Rollbar's
  custom fingerprinting. A recommendation is provided in
  [doc/rollbar.md](doc/rollbar.md).
