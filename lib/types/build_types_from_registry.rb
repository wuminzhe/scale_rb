# frozen_string_literal: true

module ScaleRb
  module TypeExp
    class Type
      attr_reader :kind

      def initialize(kind)
        @kind = kind
      end
    end

    class NamedType < Type
      attr_reader :name, :params

      def initialize(name, params)
        super('named')
        @name = name
        @params = params
      end

      def to_s
        params.empty? ? name : "#{name}<#{params.map(&:to_s).join(', ')}>"
      end
    end

    class ArrayType < Type
      attr_reader :item, :len

      def initialize(item, len)
        super('array')
        @item = item
        @len = len
      end

      def to_s
        "[#{item}; #{len}]"
      end
    end

    class TupleType < Type
      attr_reader :params

      def initialize(params)
        super('tuple')
        @params = params
      end

      def to_s
        "(#{params.map(&:to_s).join(', ')})"
      end
    end

    def self.print(type)
      type.to_s
    end

    def self.parse(type_exp)
      TypeExpParser.new(type_exp).parse
    end

    class TypeExpParser
      def initialize(type_exp)
        @type_exp = type_exp
        @tokens = tokenize(type_exp)
        @idx = 0
      end

      def self.tokenize(type_exp)
        new(type_exp).send(:tokenize, type_exp)
      end

      def parse
        type = assert(any_type)
        raise abort unless eof?

        type
      end

      private

      def eof?
        @idx >= @tokens.length
      end

      def tok(tok)
        return nil if eof?

        current = @tokens[@idx]
        match = tok.is_a?(Regexp) ? !current.nil? && tok.match?(current) : current == tok
        @idx += 1 if match
        match ? current : nil
      end

      def assert_tok(tok)
        assert(tok(tok))
      end

      def nat
        tok(/^\d+$/)&.to_i
      end

      def assert_nat
        assert(nat)
      end

      def name_tok
        tok(/^[a-zA-Z]\w*$/)
      end

      def assert_name
        assert(name_tok)
      end

      def list(sep)
        result = []
        item = yield
        return result if item.nil?

        result << item
        while tok(sep)
          item = yield
          break if item.nil?

          result << item
        end
        result
      end

      def tuple
        return nil unless tok('(')

        params = list(',') { any_type }
        assert_tok(')')
        TupleType.new(params)
      end

      def array
        return nil unless tok('[')

        item = assert(any_type)
        assert_tok(';')
        len = assert_nat
        tok(';') && assert_name
        assert_tok(']')
        ArrayType.new(item, len)
      end

      def named_type
        name = name_tok
        return nil if name.nil?

        trait = nil
        item = nil

        if tok('<')
          trait = assert_named_type.name
          assert_tok('as')
          name = assert_named_type.name
          assert_tok('>')
        end

        while tok('::')
          next_part = name_tok
          if next_part.nil?
            # Handle cases like 'EthHeaderBrief::<T::AccountId>'
            raise abort unless tok('<')

            params = type_parameters
            return NamedType.new(name, params)

          end
          item = next_part
          name = "#{name}::#{item}"
        end

        if name == 'InherentOfflineReport' && name == trait && item == 'Inherent'
          # Do nothing
        elsif name == 'exec' && item == 'StorageKey'
          name = 'ContractStorageKey'
        elsif name == 'Lookup' && item == 'Source'
          name = 'LookupSource'
        elsif name == 'Lookup' && item == 'Target'
          name = 'LookupTarget'
        elsif item
          assert(trait != 'HasCompact')
          name = item
        elsif trait == 'HasCompact'
          return NamedType.new('Compact', [NamedType.new(name, type_parameters)])
        end

        params = tok('<') ? type_parameters : []
        NamedType.new(name, params)
      end

      def assert_named_type
        assert(named_type)
      end

      def type_parameters
        params = list(',') { nat || any_type }
        assert_tok('>')
        params
      end

      def pointer_bytes
        return nil unless tok('&')

        tok("'") && assert_tok('static')
        assert_tok('[')
        assert_tok('u8')
        assert_tok(']')
        NamedType.new('Vec', [NamedType.new('u8', [])])
      end

      def any_type
        tuple || array || named_type || pointer_bytes
      end

      def abort
        StandardError.new("Invalid type expression: #{@type_exp}")
      end

      def assert(val)
        raise abort if val.nil? || val == false

        val
      end

      def tokenize(type_exp)
        tokens = []
        current_token = ''
        skip_next = false

        type_exp.each_char.with_index do |char, index|
          if skip_next
            skip_next = false
            next
          end

          if char == ':' && type_exp[index + 1] == ':'
            tokens << current_token unless current_token.empty?
            tokens << '::'
            current_token = ''
            skip_next = true
          elsif char == "'"
            tokens << current_token unless current_token.empty?
            tokens << "'"
            current_token = ''
          elsif /\w/.match?(char)
            current_token += char
          else
            tokens << current_token unless current_token.empty?
            tokens << char unless char.strip.empty?
            current_token = ''
          end
        end

        tokens << current_token unless current_token.empty?
        tokens
      end
    end
  end
end
