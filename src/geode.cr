require "cling"
require "cling/ext"
require "colorize"
require "yaml"

require "./commands/*"
require "./shard"

Colorize.on_tty_only!

module Geode
  VERSION = "0.1.0"

  BUILD_DATE = {% if flag?(:win32) %}
                 {{ `powershell.exe -NoProfile Get-Date -Format "yyyy-MM-dd"`.stringify.chomp }}
               {% else %}
                 {{ `date +%F`.stringify.chomp }}
               {% end %}

  BUILD_HASH  = {{ `git rev-parse HEAD`.stringify[0...8] }}
  HOST_TRIPLE = {{ Crystal::DESCRIPTION.split("target:").last.strip }}

  class CLI < Commands::BaseCommand
    def setup : Nil
      @name = "app"
      @header = %(#{"Geode".colorize.magenta}: #{"A Crystal Package Manager".colorize.light_magenta})

      add_command Commands::Version.new
      add_command Commands::Init.new
      add_command Commands::New.new
      add_command Commands::Install.new
      # add_command Commands::Add.new
      # add_command Commands::Check.new
      # add_command Commands::Update.new
      add_command Commands::Build.new
      # add_command Commands::Vendor.new
      # add_command Commands::Remove.new
      # add_command Commands::List.new
      # add_command Commands::Info.new
      add_command Commands::Run.new
      # add_command Commands::Config.new
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      stdout.puts help_template
    end
  end

  class SystemExit < Exception
  end
end
