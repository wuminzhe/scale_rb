require 'json'
require 'fileutils'

module ScaleRb
  module HttpClient
    class << self
      # cached version of get_metadata
      # get metadata from cache first
      def get_metadata_cached(url, at: nil, dir: File.join(Dir.pwd, 'metadata'))
        # if at
        #   require_block_hash_correct(url, at)
        # else
        #   at = ScaleRb::HttpClient.chain_getFinalizedHead(url)
        # end
        at = ScaleRb::HttpClient.chain_getFinalizedHead(url) if at.nil?
        spec_name, spec_version = get_spec(url, at)

        # get metadata from cache first
        metadata = metadata_cached(
          spec_name: spec_name,
          spec_version: spec_version,
          dir: dir
        )
        return metadata if metadata

        # get metadata from rpc
        metadata = ScaleRb::HttpClient.get_metadata(url, at)

        # cache it
        puts "caching metadata `#{spec_name}_#{spec_version}.json`"
        save_metadata_to_file(
          spec_name: spec_name,
          spec_version: spec_version,
          metadata: metadata,
          dir: dir
        )

        metadata
      end

      private

      def get_spec(url, at)
        runtime_version = ScaleRb::HttpClient.state_getRuntimeVersion(url, at)
        spec_name = runtime_version['specName']
        spec_version = runtime_version['specVersion']
        [spec_name, spec_version]
      end

      def metadata_cached(spec_name:, spec_version:, dir:)
        raise 'spec_version is required' unless spec_version
        raise 'spec_name is required' unless spec_name

        file_path = File.join(dir, "#{spec_name}_#{spec_version}.json")
        return unless File.exist?(file_path)

        puts "found metadata `#{spec_name}_#{spec_version}.json` in cache"
        JSON.parse(File.read(file_path))
      end

      def save_metadata_to_file(spec_name:, spec_version:, metadata:, dir:)
        FileUtils.mkdir_p(dir)

        File.open(File.join(dir, "#{spec_name}_#{spec_version}.json"), 'w') do |f|
          f.write(JSON.pretty_generate(metadata))
        end
      end

      def require_block_hash_correct(url, block_hash)
        return unless ScaleRb::HttpClient.chain_getHeader(url, block_hash).nil?

        raise 'Unable to retrieve header and parent from supplied hash'
      end
    end
  end
end
