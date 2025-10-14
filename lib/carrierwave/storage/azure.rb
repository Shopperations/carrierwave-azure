# frozen_string_literal: true

require "uri"
require "time"
require "marcel"
require "azure_blob"

module CarrierWave
  module Storage
    class Azure < Abstract
      def store!(file)
        azure_file = CarrierWave::Storage::Azure::File.new(uploader, connection, uploader.store_path)
        azure_file.store!(file)
        azure_file
      end

      # NOTE: keep the original misspelled signature for compatibility
      def retrieve!(identifer)
        CarrierWave::Storage::Azure::File.new(uploader, connection, uploader.store_path(identifer))
      end

      def connection
        @connection ||= begin
          # preserve the param-gathering style from the old code
          account_name = uploader.public_send(:azure_storage_account_name)
          access_key   = uploader.public_send(:azure_storage_access_key)
          host         = uploader.respond_to?(:azure_storage_blob_host) ? uploader.public_send(:azure_storage_blob_host) : nil
          container    = uploader.public_send(:azure_container)

          AzureBlob::Client.new(
            account_name: account_name,
            access_key:   access_key,
            host:         host,
            container:    container
          )
        end
      end

      def cache!(new_file)
        f = CarrierWave::Storage::Azure::File.new(uploader, connection, uploader.cache_path)
        f.store!(new_file)
        f
      end

      def delete_dir!(_path)
        # do nothing, because there's no such things as 'empty directory'
      end

      class File
        attr_reader :path

        def initialize(uploader, connection, path)
          @uploader     = uploader
          @connection   = connection
          @path         = path
          @blob         = nil          # to mimic old API (blob.properties)
          @blob_meta    = nil          # metadata/properties holder
          @content      = nil
          @content_type = nil
        end

        def store!(file)
          @content = file.respond_to?(:read) ? file.read : file.to_s
          @content_type =
            if file.respond_to?(:content_type) && file.content_type
              file.content_type
            else
              # infer from final name/path (covers versions that change extension)
              name = if file.respond_to?(:original_filename) && file.original_filename
                       file.original_filename
                     else
                       ::File.basename(@path)
                     end
              Marcel::MimeType.for(name: name) || "application/octet-stream"
            end

          @connection.create_block_blob(@path, @content, content_type: @content_type)
          true
        end

        def url(_options = {})
          path = ::File.join(@uploader.azure_container, @path)

          if @uploader.asset_host
            "#{@uploader.asset_host}/#{path}"
          else
            # Old code built a base URI then appended a service SAS token.
            # Generate the base URI from the connection's host and append SAS token
            signed = @connection.signed_uri(@path, permissions: "r", expiry: default_expiry)
            # If we have a storage_blob_host, use it to build the URL with SAS token
            if @uploader.respond_to?(:azure_storage_blob_host) && @uploader.azure_storage_blob_host
              "#{@uploader.azure_storage_blob_host}/#{path}?#{service_sas_token(path)}"
            else
              signed.to_s
            end
          end
        end

        def read
          content
        end

        def content_type
          @content_type ||= begin
            ensure_blob_meta!
            # try modern meta first
            if @blob_meta && @blob_meta.respond_to?(:content_type)
              @blob_meta.content_type
            else
              # last resort, infer from filename to avoid nil during destroy
              Marcel::MimeType.for(name: filename) || "application/octet-stream"
            end
          end
        end

        def content_type=(new_content_type)
          @content_type = new_content_type
        end

        # preserve original quirky behavior (true when blob.nil?)
        def exitst?
          blob.nil?
        end

        def size
          ensure_blob_meta!
          # support either meta.size or meta.content_length depending on client
          if @blob_meta
            @blob_meta.respond_to?(:size) ? @blob_meta.size : (@blob_meta.respond_to?(:content_length) ? @blob_meta.content_length : nil)
          end
        end

        def filename
          URI(url).path.split('/').last
        end

        def extension
          @path.split('.').last
        end

        def delete
          @connection.delete_blob(@path)
          true
        rescue AzureBlob::Http::FileNotFoundError
          false
        end

        private

        # Maintain old public helpers by name/shape:

        def blob
          load_content if @blob.nil?
          @blob
        end

        def content
          load_content if @content.nil?
          @content
        end

        def load_content
          begin
            # In the old SDK get_blob returned [blob, content].
            # New client typically splits: get_blob (body) + get_blob_properties (meta).
            @content   = @connection.get_blob(@path)
            @blob_meta = @connection.get_blob_properties(@path)
            # To preserve old API that expected `blob.properties[...]`,
            # let @blob be the meta object (it responds to .content_type/.content_length etc.)
            @blob = @blob_meta
          rescue AzureBlob::Http::FileNotFoundError
            @blob = nil
            @content = nil
          end
        end

        def ensure_blob_meta!
          return if @blob_meta
          @blob_meta = @connection.get_blob_properties(@path)
        rescue AzureBlob::Http::FileNotFoundError
          @blob_meta = nil
        end

        # Replaces the old azure-storage-common SAS generator.
        # Returns *only* the query string (without leading '?'), to match old usage.
        def service_sas_token(_path)
          signed = @connection.signed_uri(@path, permissions: "r", expiry: default_expiry)
          signed.query.to_s
        end

        def default_expiry
          # 1 hour default to mimic previous behavior; adjust if you expose a config
          Time.now.utc + 3600
        end
      end
    end
  end
end
