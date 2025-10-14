# Carrierwave::Azure

Windows Azure blob storage support for [CarrierWave](https://github.com/carrierwaveuploader/carrierwave)

## Installation

Add this line to your application's Gemfile:

    gem 'carrierwave-azure'

And then execute:

    $ bundle

## Usage

First configure CarrierWave with your Azure storage credentials

see [Azure/azure-sdk-for-ruby](https://github.com/Azure/azure-sdk-for-ruby#via-code)

```ruby
CarrierWave.configure do |config|
  config.azure_storage_account_name = 'YOUR STORAGE ACCOUNT NAME'
  config.azure_storage_access_key = 'YOUR STORAGE ACCESS KEY'
  config.azure_storage_blob_host = 'YOUR STORAGE BLOB HOST' # optional
  config.azure_container = 'YOUR CONTAINER NAME'
  config.asset_host = 'YOUR CDN HOST' # optional
end
```

And then in your uploader, set the storage to `:azure`

```ruby
class ExampleUploader < CarrierWave::Uploader::Base
  storage :azure
end
```

## Contributing

### Running Tests Locally with Azurite

This project uses [Azurite](https://github.com/Azure/Azurite), an Azure Storage emulator, for running tests locally without requiring real Azure credentials.

#### Quick Start with Docker

1. Start Azurite using Docker:

```bash
docker run --rm -p 10000:10000 -p 10001:10001 -p 10002:10002 mcr.microsoft.com/azure-storage/azurite
```

2. In another terminal, run the tests:

```bash
cp spec/environment.ci.rb spec/environment.rb
bundle install
bundle exec rspec spec
```

The tests are pre-configured to use Azurite's default credentials and will automatically create the necessary test container.

#### Alternative: Using npm

If you prefer to use npm instead of Docker:

```bash
npm install -g azurite
azurite --silent --location /tmp/azurite --debug /tmp/azurite/debug.log
```

Then run the tests as described above.

### Running Tests with Real Azure Storage

If you need to test against real Azure Storage, create a `spec/environment.rb` file with your Azure credentials:

```ruby
CarrierWave.configure do |config|
  config.azure_storage_account_name = 'YOUR STORAGE ACCOUNT NAME'
  config.azure_storage_access_key = 'YOUR STORAGE ACCESS KEY'
  config.azure_storage_blob_host = 'YOUR STORAGE BLOB HOST' # optional
  config.azure_container = 'YOUR CONTAINER NAME'
end
```

### Contributing Changes

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
