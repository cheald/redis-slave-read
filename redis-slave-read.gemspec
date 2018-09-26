# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis-slave-read/version'

Gem::Specification.new do |gem|
  gem.name          = 'redis-slave-read'
  gem.version       = Redis::SlaveRead::VERSION
  gem.authors       = ['Chris Heald']
  gem.email         = ['cheald@gmail.com']
  gem.description   = 'Provides load balancing of reads in a cluster of Redis replicas'
  gem.summary       = 'Provides load balancing of reads in a cluster of Redis replicas'
  gem.homepage      = ''

  gem.files         = `git ls-files -z`.split("\x0")
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_runtime_dependency 'connection_pool'
  gem.add_runtime_dependency 'redis', '>= 0', '>= 0'
end
