lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'satellite/version'

Gem::Specification.new do |spec|
  spec.name = 'satellite'
  spec.version = Satellite::VERSION
  spec.author = "kyosnd"
  spec.summary = ""
  spec.description = ""
  spec.email = "kyosnd+github@gmail.com"
  spec.homepage = "https://github.com/kyosnd/satellite"
  spec.license       = 'MIT'

  spec.require_paths = ["lib"]
  spec.files         = `git ls-files`.split($/).reject{|f| f == "Gemfile.lock" }

  spec.add_dependency 'json', '~> 2.6.1'
  spec.add_dependency 'openssl', '~> 3.0.0'
  spec.add_dependency 'timeout', '~> 0.2.0'
  spec.add_dependency 'uri', '~> 0.11.0'
  spec.add_dependency 'websocket', '~> 1.2.9'
end
