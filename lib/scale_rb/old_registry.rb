# frozen_string_literal: true

require_relative './types'

# rubocop:disable all
module ScaleRb
  class OldRegistry
    include Types

    # Map name to index of type in `types` array
    # % lookup :: String -> Integer
    attr_reader :lookup

    # % keys :: Integer -> String
    attr_reader :keys

    # % types :: Array<PortableType>
    attr_reader :types

    attr_reader :old_types

    # % initialize :: Hash<Symbol, Any> -> void
    def initialize(old_types)
      @old_types = old_types
      @lookup = {}
      @keys = {}
      @types = []

      build()
    end

    def build()
      @old_types.keys.each do |name|
        use(name.to_s)
      end
    end

    def [](identifier)
      if identifier.is_a?(::Integer)
        @types[identifier]
      elsif identifier.is_a?(::String)
        @types[use(identifier)]
      else
        raise "Unknown identifier type: #{identifier.class}"
      end
    end

    def inspect
      "registry(#{@types.length} types)"
    end

    def to_s
      @types.map.with_index do |type, index|
        "#{@keys[index]} => #{type.to_s}"
      end.join("\n")
    end

    # % use :: String -> Integer
    def use(old_type_exp)
      raise "Empty old_type_exp: #{old_type_exp}" if old_type_exp.nil? || old_type_exp.strip == ''

      ast_type = TypeExp.parse(old_type_exp)
      raise "No AST type for #{old_type_exp}" if ast_type.nil?

      key = ast_type.to_s
      ti = lookup[key]
      return ti if ti

      ti = @types.length
      @types[ti] = "Placeholder"
      @lookup[key] = ti
      @keys[ti] = key
      @types[ti] = build_portable_type(ast_type)
      ti
    end

    # % build_portable_type :: NamedType | ArrayType | TupleType -> PortableType
    # __ :build_portable_type, { ast_type: TypedArray[TypeExp::ArrayType | TypeExp::TupleType | TypeExp::NamedType] } => PortableType
    def build_portable_type(ast_type)
      case ast_type
      when TypeExp::ArrayType
        ArrayType.new(use(ast_type.item), ast_type.len, registry: self)
      when TypeExp::TupleType
        TupleType.new(ast_type.params.map { |param| use(param) })
      when TypeExp::NamedType
        build_portable_type_from_named_type(ast_type)
      else
        raise "Unknown type: #{ast_type.class}"
      end
    end

    # % build_portable_type_from_named_type :: NamedType -> PortableType
    def build_portable_type_from_named_type(named_type)
      name = named_type.name
      params = named_type.params

      definition = @old_types[name.to_sym]
      return build_from_definition(name, definition) if definition

      primitive = as_primitive(name)
      return primitive if primitive

      case name
      when 'Vec'
        item_index = use(params[0].to_s)
        SequenceType.new(type: item_index, registry: self)
      when 'Option'
        item_index = use(params[0].to_s)
        VariantType.option(item_index, self)
      when 'Result'
        ok_index = use(params[0].to_s)
        err_index = use(params[1].to_s)
        VariantType.result(ok_index, err_index, self)
      when 'Compact'
        # item_index = use(params[0].to_s)
        # CompactType.new(type: item_index, registry: self)
        CompactType.new
      when 'Null'
        UnitType.new
      else
        raise "Unknown type: #{name}"
      end
    end

    # % as_primitive :: String -> PrimitiveType | nil
    def as_primitive(name)
      case name.downcase
      when /^i\d+$/
        PrimitiveType.new(primitive: "I#{name[1..]}".to_sym)
      when /^u\d+$/
        PrimitiveType.new(primitive: "U#{name[1..]}".to_sym)
      when /^bool$/
        PrimitiveType.new(primitive: :Bool)
      when /^str$/, /^text$/
        PrimitiveType.new(primitive: :Str)
      else
        nil
      end
    end

    # % build_from_definition :: String -> OldTypeDefinition -> PortableType | TypeAlias
    #
    # type OldTypeDefinition = String | OldEnumDefinition | OldStructDefinition
    # type OldEnumDefinition = {
    #   _enum: String[] | Hash<Symbol, Any>,
    # }
    # type OldStructDefinition = {
    #   _struct: Hash<Symbol, Any>
    # }
    def build_from_definition(name, definition) # rubocop:disable Metrics/MethodLength
      case definition
      when String
        # TypeAlias.new(name, use(definition))
        alias_type_id = use(definition)
        # p "alias_type_id: #{alias_type_id}"
        types[alias_type_id]
      when Hash
        if definition[:_enum]
          _build_portable_type_from_enum_definition(definition)
        elsif definition[:_set]
          raise 'Sets are not supported'
        else
          _build_portable_type_from_struct_definition(definition)
        end
      end
    end

    private

    def _indexed_enum?(definition)
      definition[:_enum].is_a?(::Hash) && definition[:_enum].values.all? { |value| value.is_a?(::Integer) }
    end

    # % _build_portable_type_from_enum_definition :: Hash<Symbol, Any> -> VariantType
    def _build_portable_type_from_enum_definition(definition)
      variants =
        if definition[:_enum].is_a?(::Array)
          # Simple array enum:
          # {
          #   _enum: ['A', 'B', 'C']
          # }
          definition[:_enum].map.with_index do |variant_name, index|
            SimpleVariant.new(name: variant_name.to_sym, index:)
          end
        elsif definition[:_enum].is_a?(::Hash)
          if _indexed_enum?(definition)
            # Indexed enum:
            # {
            #   _enum: {
            #     Variant1: 0,
            #     Variant2: 1,
            #     Variant3: 2
            #   }
            # }
            definition[:_enum].map do |variant_name, index|
              SimpleVariant.new(name: variant_name, index:)
            end
          else
            # Mixed enum:
            # {
            #   _enum: {
            #     A: 'u32',
            #     B: {a: 'u32', b: 'u32'},
            #     C: null,
            #     D: ['u32', 'u32']
            #   }
            # }
            definition[:_enum].map.with_index do |(variant_name, variant_def), index|
              case variant_def
              when ::String
                TupleVariant.new(
                  name: variant_name,
                  index:,
                  tuple: TupleType.new(
                    tuple: [use(variant_def)],
                    registry: self
                  ),
                )
              when ::Array
                TupleVariant.new(
                  name: variant_name,
                  index:,
                  tuple: TupleType.new(
                    tuple: variant_def.map { |field_type| use(field_type) },
                    registry: self
                  )
                )
              when ::Hash
                StructVariant.new(
                  name: variant_name,
                  index:,
                  struct: StructType.new(
                    fields: variant_def.map do |field_name, field_type|
                      Field.new(name: field_name.to_s, type: use(field_type))
                    end,
                    registry: self
                  )
                )
              else
                raise "Unknown variant type for #{variant_name}: #{variant_def.class}"
              end
            end
          end
        end
      VariantType.new(variants:, registry: self)
    end

    # % _build_portable_type_from_struct_definition :: Hash<Symbol, Any> -> StructType
    def _build_portable_type_from_struct_definition(definition)
      fields = definition.map do |field_name, field_type|
        Field.new(name: field_name.to_s, type: use(field_type))
      end
      StructType.new(fields:, registry: self)
    end
  end
end

module ScaleRb
  class OldRegistry
    module TypeExp
      class Tokenizer
        attr_reader :tokens, :index

        # % tokenize :: String -> [String]
        def initialize(type_exp)
          @tokens = tokenize(type_exp)
          @index = 0
        end

        # % next_token :: -> String
        def next_token
          token = @tokens[@index]
          @index += 1
          token
        end

        # % peek_token :: -> String
        def peek_token
          @tokens[@index]
        end

        # % eof? :: -> Bool
        def eof?
          @index >= @tokens.length
        end

        private

        def tokenize(type_exp)
          tokens = []
          current_token = ''

          type_exp.each_char do |char|
            case char
            when /[a-zA-Z0-9_]/
              current_token += char
            when ':', '<', '>', '(', ')', '[', ']', ',', ';', '&', "'"
              tokens << current_token unless current_token.empty?
              if char == ':' && tokens.last == ':'
                tokens[-1] = '::'
              else
                tokens << char
              end
              current_token = ''
            when /\s/
              tokens << current_token unless current_token.empty?
              current_token = ''
            else
              raise abort
            end
          end

          tokens << current_token unless current_token.empty?
          tokens
        end
      end

      class NamedType
        attr_reader :name, :params

        def initialize(name, params)
          @name = name
          @params = params
        end

        def to_s
          params.empty? ? name : "#{name}<#{params.map(&:to_s).join(', ')}>"
        end
      end

      class ArrayType
        attr_reader :item, :len

        def initialize(item, len)
          @item = item
          @len = len
        end

        def to_s
          "[#{item}; #{len}]"
        end
      end

      class TupleType
        attr_reader :params

        def initialize(params)
          @params = params
        end

        def to_s
          "(#{params.map(&:to_s).join(', ')})"
        end
      end

      # % print :: NamedType | ArrayType | TupleType -> String
      def self.print(type)
        type.to_s
      end

      # % parse :: String -> NamedType | ArrayType | TupleType
      def self.parse(type_exp)
        TypeExpParser.new(type_exp).parse
      end

      class TypeExpParser
        def initialize(type_exp)
          @type_exp = type_exp
          @tokenizer = Tokenizer.new(type_exp)
          @current_token = @tokenizer.next_token
        end

        def parse
          build_type
        end

        private

        # Consume and return the current token, or nil if it doesn't equal the expected token.
        def expect(token)
          return unless @current_token == token

          current_token = @current_token
          @current_token = @tokenizer.next_token
          current_token
        end

        def expect!(token)
          expect(token) || raise("Expected #{token}, got #{@current_token}")
        end

        # Consume and return the current token if it matches the expected regex pattern.
        def expect_regex(pattern)
          return unless pattern.match?(@current_token)

          current_token = @current_token
          @current_token = @tokenizer.next_token
          current_token
        end

        def expect_regex!(pattern)
          expect_regex(pattern) || raise("Expected current token matching #{pattern.inspect}, got #{@current_token}")
        end

        # Consume and return a natural number (integer) if the current token matches.
        def expect_nat
          expect_regex(/^\d+$/)&.to_i
        end

        def expect_nat!
          expect_nat || raise("Expected natural number, got #{@current_token}")
        end

        def expect_name
          expect_regex(/^[a-zA-Z]\w*$/)
        end

        def expect_name!
          expect_name || raise("Expected name, got #{@current_token}")
        end

        def list(sep, &block)
          result = []
          item = block.call
          return result if item.nil?

          result << item
          while expect(sep)
            item = block.call
            break if item.nil? # (A, B,)

            result << item
          end
          result
        end

        def build_tuple_type
          return nil unless expect('(')

          params = list(',') { build_type }
          expect!(')')

          TupleType.new(params)
        end

        # [u8; 16; H128]
        # [u8; 16]
        def build_array_type
          return nil unless expect('[')

          item = build_type
          raise "Expected array item, got #{@current_token}" if item.nil?

          expect!(';')
          len = expect_nat!

          # [u8; 16; H128]
          if expect(';')
            expect_name! # Just consume the name
          end

          expect!(']')
          ArrayType.new(item, len)
        end

        def build_named_type
          name = nil
          trait = nil
          item = nil

          if expect('<')
            # Handle trait syntax: <T::Trait as OtherTrait>::Type
            #                          name     trait        item
            # '<T::InherentOfflineReport as InherentOfflineReport>::Inherent' -> 'InherentOfflineReport'
            # '<T::Balance as HasCompact>' -> 'Compact<Balance>'
            # '<T as Trait<I>>::Proposal' -> 'Proposal'
            name = build_named_type.name
            expect!('as')
            trait = build_named_type.name
            expect!('>')
          else
            name = expect_name
            return if name.nil?
          end

          # Consume the :: and get the next name
          item = expect_name while expect('::')

          # Handle special cases
          # From subsquid's code. But where are these coming from?
          if name == 'InherentOfflineReport' && name == trait && item == 'Inherent'
            # Do nothing
          elsif name == 'exec' && item == 'StorageKey'
            name = 'ContractStorageKey'
          elsif name == 'Lookup' && item == 'Source'
            name = 'LookupSource'
          elsif name == 'Lookup' && item == 'Target'
            name = 'LookupTarget'
          elsif item
            # '<T::Balance as HasCompact>::Item' will raise error
            raise "Expected item, got #{item}" if trait == 'HasCompact'

            name = item
          elsif trait == 'HasCompact' # '<T::Balance as HasCompact>'
            return NamedType.new('Compact', [NamedType.new(name, [])])
          end

          NamedType.new(name, type_parameters)
        end

        def type_parameters
          if expect('<')
            params = list(',') { expect_nat || build_type }
            expect!('>')
          else
            params = []
          end

          params
        end

        # &[u8]
        # &'static [u8]
        def build_pointer_bytes
          return nil unless expect('&') # &

          expect("'") && expect!('static')
          expect!('[')
          expect!('u8')
          expect!(']')
          NamedType.new('Vec', [NamedType.new('u8', [])])
        end

        # % build_type :: TupleType | ArrayType | NamedType
        def build_type
          build_tuple_type || build_array_type || build_named_type || build_pointer_bytes
        end
      end
    end
  end
end

# require_relative '../../metadata/metadata'

# begin
#   registry = ScaleRb::Metadata::Registry.new ScaleRb::Metadata::TYPES
#   puts registry
# rescue StandardError => e
#   puts e.message
#   puts e.backtrace.join("\n")
# end
