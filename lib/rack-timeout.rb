require_relative "rack/timeout/base"

if defined?(Rails)
  if [3,4,5,6,7].include?(Rails::VERSION::MAJOR)
    require_relative "rack/timeout/rails"
  else
    warn "RACK-TIMEOUT ******************** UNSUPPORTED RAILS VERSION: #{Rails::VERSION::MAJOR}"
  end
end
