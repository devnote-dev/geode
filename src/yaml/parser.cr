module Geode::YAML
  class Parser
    @tokens : Array(Token)
    @pos : Int32

    def initialize(@tokens)
      @pos = -1
    end

    def parse : Array(Node)
      nodes = [] of Node

      loop do
        break unless node = next_node
        nodes << node
      end

      nodes
    end

    private def next_node : Node?
      return unless token = next_token?
      parse token
    end

    private def next_token : Token
      @tokens[@pos += 1]
    end

    private def next_token? : Token?
      @tokens[@pos += 1]?
    end

    private def peek_token(places : Int32) : Token
      @tokens[places - 1]
    end

    private def prev_token : Token
      @tokens[@pos -= 1]
    end

    private def expect_next(type : Token::Type, *, allow_space : Bool = false) : Token
      token = next_token
      return token if token.type == type
      return expect_next type if token.type.space? && allow_space

      raise "expected token #{type}; got #{token.type}"
    end

    private def parse(token : Token) : Node?
      case token.type
      in .scalar?
        parse_scalar_or_mapping token
      in .colon?
        parse_mapping token
      in .pipe?
        parse_pipe_scalar token
      in .fold?
        parse_fold_scalar token
      in .list?
        parse_list token
      in .document_start?
        DocumentStart.new token.loc
      in .document_end?
        DocumentEnd.new token.loc
      in .space?
        Space.new token.loc, token.value
      in .newline?
        Newline.new token.loc
      in .eof?
        nil
      end
    end

    private def parse_scalar_or_mapping(token : Token) : Node
      if peek_token(1).type.colon?
        case peek_token(2).type
        when .space?, .newline?, .eof?
          next_token
          return parse_mapping token
        end
      end

      last = uninitialized Token
      value = String.build do |io|
        io << token.value
        last_is_space = token.value.ends_with? ' '

        last = loop do
          case (inner = next_token).type
          when .scalar?
            io << inner.value
            last_is_space = inner.value.ends_with? ' '
          when .colon?
            io << ':'
          when .list?
            io << '-'
          when .newline?, .eof?
            break inner
          end
        end
      end

      Scalar.new(token.loc & last.loc, value)
    end

    private def parse_mapping(token : Token) : Node
      key = Scalar.new token.loc, token.value
      value = next_node || Scalar.new token.loc, "null"

      Mapping.new(token.loc & value.loc, key, value)
    end

    private def parse_pipe_scalar(token : Token) : Node
      expect_next :newline, allow_space: true
      space = expect_next :space
      indent = space.value.size
      last = uninitialized Token

      value = String.build do |io|
        last = loop do
          case (inner = next_token).type
          when .scalar?
            io << inner.value
          when .newline?
            io << '\n'
          when .space?
            break inner if inner.value.size < indent
          else
            break inner
          end
        end
      end

      value = value.rstrip('\n') + "\n"

      Scalar.new(token.loc & last.loc, value)
    end

    private def parse_fold_scalar(token : Token) : Node
      expect_next :newline, allow_space: true
      space = expect_next :space
      indent = space.value.size
      last = uninitialized Token

      value = String.build do |io|
        last = loop do
          case (inner = next_token).type
          when .scalar?
            io << inner.value
          when .space?
            break inner if inner.value.size < indent
          when .newline?
            io << ' '
          else
            break inner
          end
        end
      end

      value = value.rstrip + "\n"

      Scalar.new(token.loc & last.loc, value)
    end

    private def parse_list(token : Token) : Node
      values = [] of Node
      prev_token

      last = loop do
        break token unless inner = next_token?
        case inner.type
        when .list?
          if node = parse next_token
            values << node
          else
            values << Scalar.new(inner.loc, "null")
            break inner
          end
        when .space?, .newline?
          next
        else
          prev_token
          break inner
        end
      end

      List.new(token.loc & last.loc, values)
    end
  end
end
