require "uri"
require "azure_blob" # provides AzureBlob::Client

module CarrierWave
  module Storage
    class Azure < Abstract
      def store!(file)
        azure_file = CarrierWave::Storage::Azure::File.new(uploader, connection, uploader.store_path)
        azure_file.store!(file)
        azure_file
      end

      def retrieve!(identifier)
        CarrierWave::Storage::Azure::File.new(uploader, connection, uploader.store_path(identifier))
      end

      def cache!(new_file)
        f = CarrierWave::Storage::Azure::File.new(uploader, connection, uploader.cache_path)
        f.store!(new_file)
        f
      end

      def delete_dir!(_path)
        # no-op; Azure Blob has no empty directories
      end

      # Build or memoize the azure-blob client
      def connection
        @connection ||= begin
          account_name = uploader.azure_storage_account_name
          access_key   = uploader.azure_storage_access_key
          container    = uploader.azure_container
          host         = uploader.respond_to?(:azure_storage_blob_host) ? uploader.azure_storage_blob_host : nil

          AzureBlob::Client.new(
            account_name: account_name,
            access_key:   access_key,
            container:    container,
            host:         host
          )
        end
      end

      class File
        attr_reader :path

        def initialize(uploader, connection, path)
          @uploader   = uploader
          @connection = connection
          @path       = path
          @blob_meta  = nil
          @content    = nil
          @content_type = nil
        end

        # Upload the IO or string content
        def store!(file)
          io = file.respond_to?(:to_io) ? file.to_io : StringIO.new(file.read)
          @content_type = file.content_type if file.respond_to?(:content_type)
          @connection.create_block_blob(@path, io, content_type: @content_type)
          true
        end

        # Public or signed URL
        def url(options = {})
          full_key = @path

          if @uploader.asset_host
            # Keep old behavior: asset_host + container/path
            path = ::File.join(@uploader.azure_container, full_key)
            "#{@uploader.asset_host}/#{path}"
          else
            # Signed URI (read). Default 1 hour, override via :expires_in
            expires_in = (options[:expires_in] || 3600).to_i
            @connection.signed_uri(full_key, permissions: "r", expiry: Time.now.utc + expires_in).to_s
          end
        end

        def read
          load_content_if_needed
          @content
        end

        def content_type
          return @content_type if @content_type
          ensure_blob_meta!
          @blob_meta&.content_type
        end

        def content_type=(new_type)
          @content_type = new_type
        end

        # Keep the typo for compatibility (mirrors existing API)
        def exitst?
          !exists?
        end

        def exists?
          @connection.blob_exist?(@path)
        rescue AzureBlob::Http::FileNotFoundError
          false
        end

        def size
          ensure_blob_meta!
          @blob_meta&.size
        end

        def filename
          URI(url).path.split("/").last
        end

        def extension
          @path.split(".").last
        end

        def delete
          @connection.delete_blob(@path)
          true
        rescue AzureBlob::Http::FileNotFoundError
          false
        end

        private

        def ensure_blob_meta!
          @blob_meta ||= @connection.get_blob_properties(@path)
        rescue AzureBlob::Http::FileNotFoundError
          @blob_meta = nil
        end

        def load_content_if_needed
          return if @content
          @content = @connection.get_blob(@path)
        rescue AzureBlob::Http::FileNotFoundError
          @content = nil
        end
      end
    end
  end
end
