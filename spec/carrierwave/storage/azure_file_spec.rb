require 'spec_helper'

describe CarrierWave::Storage::Azure::File do
  class TestUploader < CarrierWave::Uploader::Base
    storage :azure
  end

  let(:uploader) { TestUploader.new }
  let(:storage)  { CarrierWave::Storage::Azure.new uploader }

  describe '#url' do
    let(:azure_file) { CarrierWave::Storage::Azure::File.new(uploader, storage.connection, 'dummy.txt') }

    context 'with asset_host' do
      before do
        allow(uploader).to receive(:azure_container).and_return('test')
        allow(uploader).to receive(:asset_host).and_return('http://example.com')
      end

      it 'should return asset_host URL without SAS token' do
        url = azure_file.url
        expect(url).to eq "http://example.com/test/dummy.txt"
      end
    end

    context 'without asset_host' do
      before do
        allow(uploader).to receive(:azure_container).and_return('test')
        allow(uploader).to receive(:asset_host).and_return(nil)
      end

      it 'should return a signed URL with SAS token' do
        url = azure_file.url
        # Should be a full URL with SAS query parameters
        expect(url).to match(/^https?:\/\//)
        expect(url).to include('sig=') # SAS signature
        expect(url).to include('se=')  # expiry
        expect(url).to include('sp=')  # permissions
      end

      it 'should respect expires_in option' do
        url1 = azure_file.url(expires_in: 7200)
        url2 = azure_file.url(expires_in: 7200)
        # Should generate the same URL when called with same expiry
        expect(url1).to eq(url2)
      end
    end
  end
end
