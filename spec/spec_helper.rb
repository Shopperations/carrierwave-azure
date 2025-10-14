require 'rubygems'
require 'rspec'
require 'carrierwave'
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
