module Geode::Commands
  protected def self.format_command(command : Cling::Command) : String
    String.build do |str|
      if header = command.header
        str << header << '\n'
      else
        str << "Command".colorize.magenta << " • " << command.name << '\n'
      end
      str << '\n'

      if description = command.description
        str << description
        str << "\n\n"
      end

      unless command.usage.empty?
        str << "Usage".colorize.magenta << '\n'
        command.usage.each { |use| str << "»  " << use << '\n' }
        str << '\n'
      end

      unless command.children.empty?
        str << "Commands".colorize.magenta << '\n'
        max_size = 4 + commands.children.keys.max_of &.size

        command.children.each do |name, cmd|
          str << "»  " << name
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
        max_size = 4 + command.arguments.keys.max_of &.size

        command.arguments.each do |name, argument|
          str << "»  " << name
          str << " " * (max_size - name.size)
          str << argument.description
          str << " (required)" if argument.required?
          str << '\n'
        end
        str << '\n'
      end

      str << "Options".colorize.magenta << '\n'
      max_size = 2 + command.options.max_of { |n, o| 2 + n.size + (o.short ? 2 : 0) }

      command.options.each do |name, option|
        name_size = 2 + option.long.size + (option.short ? 2 : -2)

        str << "»  "
        if short = option.short
          str << '-' << short << ", "
        end
        str << "--" << name
        str << " " * (max_size - name_size)
        str << option.description

        if default = option.default
          str << " (default: " << default << ')'
        end
        str << '\n'
      end
    end
  end
end
