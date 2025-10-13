# frozen_string_literal: true

require "uri"
require "marcel"
require "azure_blob"

module CarrierWave
  module Storage
    class Azure < Abstract
      def store!(file)
        azure_file = File.new(uploader, connection, uploader.store_path)
        azure_file.store!(file)
        azure_file
      end

      def retrieve!(identifier)
        File.new(uploader, connection, uploader.store_path(identifier))
      end

      def connection
        @connection ||= AzureBlob::Client.new(
          account_name: uploader.azure_storage_account_name,
          access_key:   uploader.azure_storage_access_key,
          container:    uploader.azure_container,
          host:         uploader.try(:azure_storage_blob_host)
        )
      end

      class File
        attr_reader :path

        def initialize(uploader, connection, path)
          @uploader   = uploader
          @connection = connection
          @path       = path
          @content_type = nil
          @blob_meta  = nil
        end

        def store!(file)
          data = file.respond_to?(:read) ? file.read : file.to_s
          @content_type = detect_content_type(file)
          @connection.create_block_blob(@path, data, content_type: @content_type)
        end

        def url(options = {})
          if @uploader.asset_host
            "#{@uploader.asset_host}/#{@uploader.azure_container}/#{@path}"
          else
            expires_in = (options[:expires_in] || 3600).to_i
            @connection.signed_uri(@path, permissions: "r", expiry: Time.now.utc + expires_in).to_s
          end
        end

        def content_type
          return @content_type if @content_type
          ensure_blob_meta!
          @content_type = @blob_meta&.content_type ||
                          Marcel::MimeType.for(name: filename) ||
                          "application/octet-stream"
        end

        def exists?
          @connection.blob_exist?(@path)
        rescue AzureBlob::Http::FileNotFoundError
          false
        end

        def delete
          @connection.delete_blob(@path)
        rescue AzureBlob::Http::FileNotFoundError
          false
        end

        def filename
          ::File.basename(@path)
        end

        private

        def ensure_blob_meta!
          @blob_meta ||= @connection.get_blob_properties(@path)
        rescue AzureBlob::Http::FileNotFoundError
          @blob_meta = nil
        end

        def detect_content_type(file)
          return file.content_type if file.respond_to?(:content_type) && file.content_type
          if file.respond_to?(:original_filename) && file.original_filename
            Marcel::MimeType.for(name: file.original_filename)
          else
            Marcel::MimeType.for(name: filename)
          end || "application/octet-stream"
        end
      end
    end
  end
end
