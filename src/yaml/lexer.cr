module Geode::YAML
  class Lexer
    @pool : StringPool
    @reader : Char::Reader
    @line : Int32
    @column : Int32
    @loc : Location

    def initialize(source : String)
      @pool = StringPool.new
      @reader = Char::Reader.new source
      @line = @column = 0
      @loc = Location.new 0, 0
    end

    def run : Array(Token)
      tokens = [] of Token

      loop do
        token = next_token
        tokens << token
        break if token.type.eof?
      end

      tokens
    end

    private def next_token : Token
      @loc = Location.new @line, @column

      case current_char
      when '\0'
        Token.new :eof, current_loc
      when ' '
        lex_space
      when '\r', '\n'
        lex_newline
      when ':'
        next_char
        Token.new :colon, current_loc
      when '|'
        next_char
        Token.new :pipe, current_loc
      when '>'
        next_char
        Token.new :fold, current_loc
      when '-'
        if next_char == '-' && next_char == '-'
          next_char
          Token.new :document_start, current_loc
        else
          Token.new :list, current_loc
        end
      when '.'
        if next_char == '.' && next_char == '.'
          next_char
          Token.new :document_end, current_loc
        else
          lex_scalar
        end
      else
        lex_scalar
      end
    end

    private def current_char : Char
      @reader.current_char
    end

    private def current_loc : Location
      @loc.line_stop = @line
      @loc.column_stop = @column

      @loc
    end

    private def next_char : Char
      @column += 1
      @reader.next_char
    end

    private def lex_space : Token
      start = @reader.pos
      while current_char == ' '
        next_char
      end

      loc = current_loc
      slice = Slice.new(
        @reader.string.to_unsafe + start,
        @reader.pos - start
      )

      Token.new :space, loc, @pool.get slice
    end

    private def lex_newline : Token
      if current_char == '\r'
        raise "expected '\\n' after '\\r'" unless next_char == '\n'
      end

      @reader.next_char
      @line += 1
      @column = 0

      Token.new :newline, current_loc
    end

    private def lex_scalar : Token
      start = @reader.pos
      until current_char.in?('\0', '\r', '\n', ':')
        next_char
      end

      loc = current_loc
      slice = Slice.new(
        @reader.string.to_unsafe + start,
        @reader.pos - start
      )

      Token.new :scalar, loc, @pool.get slice
    end
  end
end
