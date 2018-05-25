 Upgrading
 =========

 From 0.4 or older
 -----------------

 Removal of the class setters, such as `Rack::Timeout.timeout = 5`, may
 lead to an error when upgrading. To fix this, remove these setters and
 instead use either the [environment variables][config-env],
 `RACK_TIMEOUT_*`, or [insert the middleware manually][config-insert]
 and configure the middleware as desired when inserting.

 [config-env]: README.md#configuring
 [config-insert]: README.md#rails-apps-manually
