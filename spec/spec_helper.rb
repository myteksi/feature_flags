$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'feature_flags'
require 'rspec'
require 'bourne'
require 'redis'

RSpec.configure do |config|
  config.before { Redis.new.flushdb }
end
