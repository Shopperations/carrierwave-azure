CarrierWave.configure do |config|
  config.azure_storage_account_name = ENV['AZURE_STORAGE_ACCOUNT_NAME']
  config.azure_storage_access_key = ENV['AZURE_STORAGE_ACCESS_KEY']
  config.azure_container = ENV['AZURE_CONTAINER']
end
