# frozen_string_literal: true

require_relative 'lib/flashapi/version'

Gem::Specification.new do |spec|
  spec.name          = 'flashapi'
  spec.version       = FlashAPI::VERSION
  spec.authors       = ['Vasyl Melnychuk']
  spec.email         = ['vasyl@melnychuk.me']

  spec.summary       = 'Fast API framework'
  spec.description   = 'Lightweight and fast framework for your API'
  spec.homepage      = 'https://github.com/sqrel/flashapi'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .github])
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'oj', '~> 3.16'

  spec.add_development_dependency 'bundler', '~> 2.5'
  spec.add_development_dependency 'rake', '~> 13.2'
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'rubocop', '~> 1.68'
  spec.add_development_dependency 'rubocop-performance', '~> 1.23'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.3'
  spec.add_development_dependency 'rack', '~> 3.1'
  spec.add_development_dependency 'eventmachine', '~> 1.2'
  spec.add_development_dependency 'http_parser.rb', '~> 0.8'
end
