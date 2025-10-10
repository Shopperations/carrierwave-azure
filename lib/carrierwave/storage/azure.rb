# frozen_string_literal: true

require "uri"
require "time"
require "stringio"
require "azure_blob"

module CarrierWave
  module Storage
    class Azure < Abstract
      def store!(file)
        f = CarrierWave::Storage::Azure::File.new(uploader, connection, uploader.store_path)
        f.store!(file)
        f
      end

      def retrieve!(identifier)
        CarrierWave::Storage::Azure::File.new(uploader, connection, uploader.store_path(identifier))
      end

      def cache!(new_file)
        f = CarrierWave::Storage::Azure::File.new(uploader, connection, uploader.cache_path)
        f.store!(new_file)
        f
      end

      def delete_dir!(_path); end

      def connection
        @connection ||= Client.new(
          account_name: uploader.azure_storage_account_name,
          access_key:   uploader.azure_storage_access_key,
          container:    uploader.azure_container,
          host:         (uploader.respond_to?(:azure_storage_blob_host) ? uploader.azure_storage_blob_host : nil)
        )
      end

      class Client
        BlobMeta = Struct.new(:content_type, :size, keyword_init: true)

        def initialize(account_name:, access_key:, container:, host: nil)
          @account   = account_name
          @key       = access_key
          @container = container
          @host      = host&.to_s&.chomp("/")
          @client    = AzureBlob::Client.new(
            account_name: @account,
            access_key:   @key,
            container:    @container,
            host:         @host
          )
        end

        def put(key, io, content_type: nil)
          @client.create_block_blob(key, io, content_type: content_type)
        end

        def get(key)
          @client.get_blob(key)
        end

        def head(key)
          p = @client.get_blob_properties(key)
          BlobMeta.new(content_type: p&.content_type, size: p&.content_length || p&.size)
        end

        def exist?(key)
          @client.blob_exist?(key)
        end

        def delete(key)
          @client.delete_blob(key)
        end

        def public_url(key)
          raise "host not configured" unless @host
          "#{@host}/#{@container}/#{key}"
        end

        def signed_url(key, permissions:, expiry:)
          @client.signed_uri(key, permissions: permissions, expiry: expiry).to_s
        end
      end

      class File
        attr_reader :path

        def initialize(uploader, connection, path)
          @uploader   = uploader
          @connection = connection
          @path       = path
          @meta       = nil
          @content    = nil
          @ctype      = nil
          @sas_cache  = {}
        end

        def store!(file)
          io =
            if file.respond_to?(:to_io) && file.to_io
              file.to_io
            elsif file.respond_to?(:file) && file.file.respond_to?(:to_io)
              file.file.to_io
            elsif file.respond_to?(:tempfile) && file.tempfile.respond_to?(:to_io)
              file.tempfile.to_io
            else
              data = file.respond_to?(:read) ? file.read.to_s : file.to_s
              StringIO.new(data)
            end
          @ctype = file.content_type if file.respond_to?(:content_type)
          @connection.put(@path, io, content_type: @ctype)
          true
        end

        def url(options = {})
          if @uploader.asset_host
            path_with_container = ::File.join(@uploader.azure_container, @path)
            return "#{@uploader.asset_host}/#{path_with_container}"
          end

          expiry =
            if options[:expires_at]
              t = options[:expires_at]
              t = Time.parse(t.to_s) unless t.is_a?(Time)
              t.utc
            else
              ttl = options[:expires_in] ||
                    (@uploader.respond_to?(:azure_url_expires_in) && @uploader.azure_url_expires_in) ||
                    3600
              Time.now.utc + ttl.to_i
            end

          perms = options[:permissions] || "r"
          cache_key = [@path, perms, expiry.to_i]

          @sas_cache[cache_key] ||= begin
            if public_container?
              @connection.public_url(@path)
            else
              @connection.signed_url(@path, permissions: perms, expiry: expiry)
            end
          end
        end

        def read
          load_content_if_needed
          @content
        end

        def content_type
          return @ctype if @ctype
          ensure_meta!
          @meta&.content_type
        end

        def content_type=(new_ctype)
          @ctype = new_ctype
        end

        def exitst?
          !exists?
        end

        def exists?
          @connection.exist?(@path)
        rescue StandardError
          false
        end

        def size
          ensure_meta!
          @meta&.size
        end

        def filename
          URI(url).path.split("/").last
        end

        def extension
          @path.split(".").last
        end

        def delete
          @connection.delete(@path)
          true
        rescue StandardError
          false
        end

        private

        def ensure_meta!
          @meta ||= @connection.head(@path)
        rescue StandardError
          @meta = nil
        end

        def load_content_if_needed
          return if @content
          @content = @connection.get(@path)
        rescue StandardError
          @content = nil
        end

        def public_container?
          @uploader.respond_to?(:azure_public) && !!@uploader.azure_public
        end
      end
    end
  end
end
