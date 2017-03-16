# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'flashapi/version'

Gem::Specification.new do |spec|
  spec.name          = "flashapi"
  spec.version       = FlashAPI::VERSION
  spec.authors       = ["Vasilij Melnychuk"]
  spec.email         = ["vasilij@melnychuk.me"]

  spec.summary       = %q{Fast API framework}
  spec.description   = %q{Lightweight and fast framework for your API}
  spec.homepage      = "http://github.com/sqrel/flashapi"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.3.0"

  spec.add_dependency "oj", "~> 2.12.8"
end
