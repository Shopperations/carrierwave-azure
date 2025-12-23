# Configuration for Azurite (Azure Storage Emulator)
# These are the well-known Azurite development credentials
CarrierWave.configure do |config|
  config.azure_storage_account_name = ENV['AZURE_STORAGE_ACCOUNT_NAME'] || 'devstoreaccount1'
  config.azure_storage_access_key = ENV['AZURE_STORAGE_ACCESS_KEY'] || 'Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=='
  config.azure_storage_blob_host = ENV['AZURE_STORAGE_BLOB_HOST'] || 'http://127.0.0.1:10000/devstoreaccount1'
  config.azure_container = ENV['AZURE_CONTAINER'] || 'test-container'
end
