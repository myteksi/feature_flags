$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'feature_flags'
require 'feature_flags/flag_rule'
require 'feature_flags/flag_accessor'
require 'feature_flags_general'
require 'rspec'
require 'bourne'
require 'redis'

RSpec.configure do |config|
  config.before { Redis.new.flushdb }
end
