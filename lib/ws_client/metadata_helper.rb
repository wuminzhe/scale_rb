module ScaleRb
  module MetadataHelper
    class << self
      def get_metadata_by_block_number(client, cache_dir, block_height=nil)
        block_hash = 
          if block_height
            client.chain_getBlockHash(block_height)
          else
            client.chain_getBlockHash
          end

        get_metadata_by_block_hash(client, cache_dir, block_hash)
      end

      def get_metadata_by_block_hash(client, cache_dir, block_hash)
        # Get metadata from cache if it exists
        runtime_version = client.state_getRuntimeVersion(block_hash)
        spec_name = runtime_version['specName']
        spec_version = runtime_version['specVersion']
        metadata = cached_metadata(spec_name: spec_name, spec_version: spec_version, dir: cache_dir)
        return metadata if metadata

        # Get metadata from node
        metadata_hex = client.state_getMetadata(block_hash)
        metadata = ScaleRb::Metadata.decode_metadata(metadata_hex.strip._to_bytes)
        save_metadata_to_file(
          spec_name: spec_name,
          spec_version: spec_version,
          metadata: metadata,
          dir: cache_dir
        )

        return metadata
      end

      private

      def cached_metadata(spec_name:, spec_version:, dir:)
        file_path = File.join(dir, "#{spec_name}-#{spec_version}.json")
        return unless File.exist?(file_path)

        JSON.parse(File.read(file_path))
      end

      def save_metadata_to_file(spec_name:, spec_version:, metadata:, dir:)
        FileUtils.mkdir_p(dir)

        File.open(File.join(dir, "#{spec_name}-#{spec_version}.json"), 'w') do |f|
          f.write(JSON.pretty_generate(metadata))
        end
      end

    end
  end
end