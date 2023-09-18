module Geode::Commands
  class Template < Base
    def setup : Nil
      @name = "template"

      add_command List.new
      # add_command Add.new
      add_command Create.new
      # add_command Test.new
      # add_command Remove.new
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      stdout.puts help_template
    end

    class List < Base
      def setup : Nil
        @name = "list"
      end

      def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
        Dir.each_child(Geode::Config::TEMPLATES) do |name|
          next unless File.exists? Geode::Config::TEMPLATES / name / "config.ini"
          next unless File.exists? Geode::Config::TEMPLATES / name / "build.lua"
          stdout << "• " << name << '\n'
        end
      end
    end

    class Create < Base
      private COMMAND = {% if flag?(:darwin) %}"Cmd"{% else %}"Ctrl"{% end %}
      private CHAR    = {% if flag?(:darwin) %}"Q"{% else %}"C"{% end %}

      def setup : Nil
        @name = "create"

        add_argument "dir"
        add_option "name", type: :single
        add_option "author", type: :single
        add_option "source", type: :single
      end

      def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
        if arguments.empty? || !(options.has?("name") && options.has?("author") && options.has?("source"))
          stdout.puts <<-INTRO
            Welcome to the Geode interactive template setup!
            Press '^#{CHAR}' (#{COMMAND} + #{CHAR}) to exit at any time.
            INTRO
          stdout.puts
        end

        dir = arguments.get?("dir").try &.as_path
        unless dir
          dir = Path[{{ flag?(:win32) ? ".\\template" : "./template" }}]
          prompt("location (#{dir}): ") do |input|
            dir = Path[input] unless input.blank?
          end
        end

        name = options.get?("name").try &.as_s
        unless name
          prompt("name: ") { |input| name = input }
        end

        author = options.get?("author").try &.as_s
        unless author
          prompt("author: ") { |input| author = input }
        end

        source = options.get?("source").try &.as_s
        unless source
          prompt("source: ") { |input| source = input }
        end

        stdout.puts "Generating files..."
        Dir.mkdir_p dir

        File.write(dir / "config.ini", <<-INI)
          id=#{name}
          author=#{author}
          source=#{source}
          INI

        # TODO: add more info
        File.write(dir / "build.lua", <<-LUA)
          print "Hello world!"
          LUA

        success "Generated template files"
        stdout.puts "This template can be added using the following command:\n"
        stdout.puts "geode template add #{source}".colorize.bold
      end

      private def prompt(message : String, & : String ->) : Nil
        loop do
          stdout << message
          input = STDIN.gets || ""
          return if input.blank?

          begin
            yield input
            break
          rescue ex
            stderr.puts "#{"»".colorize.red} #{ex.message}"
          end
        end
      end
    end
  end
end
