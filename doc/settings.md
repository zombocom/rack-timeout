# Settings

Rack::Timeout has 4 settings, each of which impacts when Rack::Timeout
will raise an exception, and which type of exception will be raised.

### Service Timeout

`service_timeout` is the most important setting.

*Service time* is the time taken from when a request first enters rack to when its response is sent back. When the application takes longer than `service_timeout` to process a request, the request's status is logged as `timed_out` and `Rack::Timeout::RequestTimeoutException` or `Rack::Timeout::RequestTimeoutError` is raised on the application thread. This may be automatically caught by the framework or plugins, so beware. Also, the exception is not guaranteed to be raised in a timely fashion, see section below about IO blocks.

Service timeout can be disabled entirely by setting the property to `0` or `false`, at which point the request skips Rack::Timeout's machinery (so no logging will be present).

### Wait Timeout

Before a request reaches the rack application, it may have spent some time being received by the web server, or waiting in the application server's queue before being dispatched to rack. The time between when a request is received by the web server and when rack starts handling it is called the *wait time*.

On Heroku, a request will be dropped when the routing layer sees no data being transferred for over 30 seconds. (You can read more about the specifics of Heroku routing's timeout [here][heroku-routing] and [here][heroku-timeout].) In this case, it makes no sense to process a request that reaches the application after having waited more than 30 seconds. That's where the `wait_timeout` setting comes in. When a request has a wait time greater than `wait_timeout`, it'll be dropped without ever being sent down to the application, and a `Rack::Timeout::RequestExpiryError` is raised. Such requests are logged as `expired`.

[heroku-routing]: https://devcenter.heroku.com/articles/http-routing#timeouts
[heroku-timeout]: https://devcenter.heroku.com/articles/request-timeout

`wait_timeout` is set at a default of 30 seconds, matching Heroku's router's timeout.

Wait timeout can be disabled entirely by setting the property to `0` or `false`.

A request's computed wait time may affect the service timeout used for it. Basically, a request's wait time plus service time may not exceed the wait timeout. The reasoning for that is based on Heroku router's behavior, that the request would be dropped anyway after the wait timeout. So, for example, with the default settings of `service_timeout=15`, `wait_timeout=30`, a request that had 20 seconds of wait time will not have a service timeout of 15, but instead of 10, as there are only 10 seconds left before `wait_timeout` is reached. This behavior can be disabled by setting `service_past_wait` to `true`. When set, the `service_timeout` setting will always be honored. Please note that if you're using the `RACK_TIMEOUT_SERVICE_PAST_WAIT` environment variable, any value different than `"false"` will be considered `true`.

The way we're able to infer a request's start time, and from that its wait time, is through the availability of the `X-Request-Start` HTTP header, which is expected to contain the time since epoch in milliseconds. (A concession is made for nginx's sec.msec notation.)

If the `X-Request-Start` header is not present `wait_timeout` handling is skipped entirely.

### Wait Overtime

Relying on `X-Request-Start` is less than ideal, as it computes the time since the request *started* being received by the web server, rather than the time the request *finished* being received by the web server. That poses a problem for lengthy requests.

Lengthy requests are requests with a body, such as POST requests. These take time to complete being received by the application server, especially when the client has a slow upload speed, as is common for example with mobile clients or asymmetric connections.

While we can infer the time since a request started being received, we can't tell when it completed being received, which would be preferable. We're also unable to tell the time since the last byte was sent in the request, which would be relevant in tracking Heroku's router timeout appropriately.

A request that took longer than 30s to be fully received, but that had been uploading data all that while, would be dropped immediately by Rack::Timeout because it'd be considered too old. Heroku's router, however, would not have dropped this request because data was being transmitted all along.

As a concession to these shortcomings, for requests that have a body present, we allow some additional wait time on top of `wait_timeout`. This aims to make up for time lost to long uploads.

This extra time is called *wait overtime* and can be set via `wait_overtime`. It defaults to 60 seconds. This can be disabled as usual by setting the property to `0` or `false`. When disabled, there's no overtime. If you want lengthy requests to never get expired, set `wait_overtime` to a very high number.

Keep in mind that Heroku [recommends][uploads] uploading large files directly to S3, so as to prevent the dyno from being blocked for too long and hence unable to handle further incoming requests.

[uploads]: https://devcenter.heroku.com/articles/s3#file-uploads
