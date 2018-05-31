Gem::Specification.new do |spec|
  spec.name        = "rack-timeout"
  spec.summary     = "Abort requests that are taking too long"
  spec.description = "Rack middleware which aborts requests that have been running for longer than a specified timeout."
  spec.version     = "0.5.1"
  spec.homepage    = "http://github.com/heroku/rack-timeout"
  spec.author      = "Caio Chassot"
  spec.email       = "caio@heroku.com"
  spec.files       = Dir[*%w( MIT-LICENSE CHANGELOG README.markdown lib/**/* doc/**/* )]
  spec.license     = "MIT"

  spec.test_files = Dir.glob("test/**/*").concat([
    "Gemfile",
    "Rakefile"
  ])

  spec.add_development_dependency("rake")
  spec.add_development_dependency("rack-test")
  spec.add_development_dependency("test-unit")
end
