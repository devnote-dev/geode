module Geode::Commands
  protected def self.format_command(command : Cling::Command) : String
    String.build do |str|
      if header = command.header
        str << header << "\n\n"
      else
        str  << "❖  Command".colorize.magenta << ": " << command.name << '\n'
      end

      if description = command.description
        str << description << "\n\n"
      end

      unless command.children.empty?
        str << "Commands".colorize.magenta << '\n'
        command.children.each do |name, cmd|
          str << "»  #{name}"
          if summary = cmd.summary
            str << '\t' << summary
          end
          str << '\n'
        end
        str << '\n'
      end

      unless command.arguments.empty?
        str << "Arguments".colorize.magenta << '\n'
        command.arguments.each do |name, argument|
          str << "»  #{name}\t#{argument.description}" << '\n'
          str << " (required)" if argument.required?
          str << '\n'
        end
      end

      str << "Options".colorize.magenta << '\n'
      max_size = command.options.map { |n, o| n.size + (o.short ? 2 : 0) + 2 }.max + 2
      command.options.each do |name, option|
        name_size = 2 + option.long.size + (option.short ? 2 : -2)

        str << "»  "
        if short = option.short
          str << '-' << short << ", "
        end
        str << "--" << name
        str << " " * (max_size - name_size)
        str << option.description << '\n'
      end
    end
  end
end
