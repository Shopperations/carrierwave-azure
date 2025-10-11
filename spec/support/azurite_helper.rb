# Helper to set up Azurite for testing
require 'azure_blob'

module AzuriteHelper
  def self.setup_test_container
    # Use the same configuration as the tests
    config = CarrierWave::Uploader::Base
    container_name = config.azure_container
    
    # Create a client with the container parameter
    client = AzureBlob::Client.new(
      account_name: config.azure_storage_account_name,
      access_key: config.azure_storage_access_key,
      host: config.azure_storage_blob_host,
      container: container_name
    )
    
    begin
      # Try to create the container (no parameter needed, uses the container from client)
      client.create_container
      puts "Created container: #{container_name}"
    rescue AzureBlob::Http::Error => e
      # Container might already exist (409 Conflict)
      # Azurite returns different error messages, so we catch all and check response
      if e.message.include?('409') || e.message.include?('ContainerAlreadyExists')
        puts "Container #{container_name} already exists"
      else
        puts "Error creating container: #{e.message}"
        # Don't fail the test suite if container creation fails
      end
    rescue => e
      puts "Unexpected error creating container: #{e.class} - #{e.message}"
      # Don't fail the test suite
    end
  end
  
  def self.cleanup_test_container
    config = CarrierWave::Uploader::Base
    container_name = config.azure_container
    
    client = AzureBlob::Client.new(
      account_name: config.azure_storage_account_name,
      access_key: config.azure_storage_access_key,
      host: config.azure_storage_blob_host,
      container: container_name
    )
    
    begin
      # List and delete all blobs in the container
      blobs = client.list_blobs(prefix: nil)
      blobs.each do |blob|
        # blob is a string (blob name), not an object
        client.delete_blob(blob)
      end
    rescue => e
      puts "Warning: Could not clean up container: #{e.message}"
    end
  end
end
