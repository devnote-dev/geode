module Geode::Commands
  protected def self.format_command(command : Cling::Command) : String
    String.build do |str|
      if header = command.header
        str << header << "\n\n"
      else
        str << "❖  Command".colorize.magenta << ": " << command.name << '\n'
      end

      if description = command.description
        group = [] of String
        text = ""

        description.split(' ').each do |word|
          text += " " + word
          if text.size >= 80
            group << text
            text = ""
          end
        end
        group << text unless text.empty?

        group.each do |line|
          str << line.strip << '\n'
        end
        str << '\n'
      end

      unless command.usage.empty?
        str << "Usage".colorize.magenta << '\n'
        command.usage.each do |use|
          str << "»  " << use << '\n'
        end
        str << '\n'
      end

      unless command.children.empty?
        str << "Commands".colorize.magenta << '\n'
        max_size = command.children.keys.map(&.size).max + 4
        command.children.each do |name, cmd|
          str << "»  #{name}"
          if summary = cmd.summary
            str << " " * (max_size - name.size)
            str << summary
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
