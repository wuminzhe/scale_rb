require 'yaml'

module ScaleRb
  module Metadata
    module TypesHelper
      class << self
        def build_types(spec_version, yaml_file)
          yaml_content = YAML.load_file(yaml_file)
          types = yaml_content['global']['types'].transform_values { |v| parse_type(v) }
          
          # Apply spec version specific overrides
          yaml_content['forSpec']&.each do |spec_range|
            range = spec_range['range']
            next unless in_range?(spec_version, range)
            
            spec_range['types']&.each do |type_name, type_def|
              types[type_name] = parse_type(type_def)
            end
          end

          types
        end

        private

        def in_range?(version, range)
          min, max = range
          return false if min && version < min
          return false if max && version > max
          true
        end

        def parse_type(type_def)
          case type_def
          when String
            type_def
          when Hash
            if type_def['_enum']
              parse_enum(type_def['_enum'])
            else
              type_def.transform_values { |v| parse_type(v) }
            end
          when Array
            type_def.map { |v| parse_type(v) }
          else
            type_def
          end
        end

        def parse_enum(enum_def)
          case enum_def
          when Array
            { '_enum' => enum_def }
          when Hash
            { '_enum' => enum_def.transform_values { |v| parse_type(v) } }
          else
            { '_enum' => enum_def }
          end
        end
      end
    end
  end
end
