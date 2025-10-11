require 'rubygems'
require 'rspec'
require 'carrierwave'

# Monkey patch for azure-blob gem compatibility with Ruby 3.2+
# The gem uses URI::RFC2396_PARSER which was removed in Ruby 3.2
# We provide a compatible shim using URI::DEFAULT_PARSER
unless defined?(URI::RFC2396_PARSER)
  module URI
    RFC2396_PARSER = URI::DEFAULT_PARSER
  end
end

require 'carrierwave-azure'
require 'environment'
require 'support/azurite_helper'

RSpec.configure do |config|
  config.order = :random
  
  # Set up the test container before running tests
  config.before(:suite) do
    AzuriteHelper.setup_test_container
  end
  
  # Clean up the test container after each test
  config.after(:each) do
    AzuriteHelper.cleanup_test_container
  end
end
