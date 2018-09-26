# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'redis-slave-read'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
end
