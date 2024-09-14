# frozen_string_literal: true

module ScaleRb
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
