# frozen_string_literal: true

require 'carrierwave'
require 'azure_blob'
require 'carrierwave/storage/azure'

class CarrierWave::Uploader::Base
  add_config :azure_storage_account_name
  add_config :azure_storage_access_key
  add_config :azure_storage_blob_host
  add_config :azure_container
  add_config :azure_public
  add_config :azure_url_expires_in

  configure do |config|
    config.storage_engines[:azure] = 'CarrierWave::Storage::Azure'
  end
end
