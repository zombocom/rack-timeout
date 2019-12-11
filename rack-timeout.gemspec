RACK_TIMEOUT_VERSION = "0.6.0"

Gem::Specification.new do |spec|
  spec.name        = "rack-timeout"
  spec.summary     = "Abort requests that are taking too long"
  spec.description = "Rack middleware which aborts requests that have been running for longer than a specified timeout."
  spec.version     = RACK_TIMEOUT_VERSION
  spec.homepage    = "https://github.com/sharpstone/rack-timeout"
  spec.author      = "Caio Chassot"
  spec.email       = "caio@heroku.com"
  spec.files       = Dir[*%w( MIT-LICENSE CHANGELOG.md UPGRADING.md README.md lib/**/* doc/**/* )]
  spec.license     = "MIT"
  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/sharpstone/rack-timeout/issues",
    "changelog_uri"     => "https://github.com/sharpstone/rack-timeout/blob/v#{RACK_TIMEOUT_VERSION}/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/rack-timeout/#{RACK_TIMEOUT_VERSION}/",
    "source_code_uri"   => "https://github.com/sharpstone/rack-timeout"
}

  spec.test_files = Dir.glob("test/**/*").concat([
    "Gemfile",
    "Rakefile"
  ])

  spec.add_development_dependency("rake")
  spec.add_development_dependency("rack-test")
  spec.add_development_dependency("test-unit")
end
