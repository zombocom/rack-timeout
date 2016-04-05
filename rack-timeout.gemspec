Gem::Specification.new do |spec|
  spec.name        = "rack-timeout"
  spec.summary     = "Abort requests that are taking too long"
  spec.description = "Rack middleware which aborts requests that have been running for longer than a specified timeout."
  spec.version     = "0.4.2"
  spec.homepage    = "http://github.com/heroku/rack-timeout"
  spec.author      = "Caio Chassot"
  spec.email       = "caio@heroku.com"
  spec.files       = Dir[*%w( MIT-LICENSE CHANGELOG README.markdown lib/**/* )]
  spec.license     = "MIT"
end
