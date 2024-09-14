module ScaleRb
  module TypeExp
    class Tokenizer
      attr_reader :tokens, :index

      def initialize(type_exp)
        @tokens = tokenize(type_exp)
        @index = 0
      end

      def next_token
        token = @tokens[@index]
        @index += 1
        token
      end

      def peek_token
        @tokens[@index]
      end

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
  end
end
