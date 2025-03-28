require "cling"
require "cling/ext"
require "colorize"
require "crystal-lua"
require "file_utils"
require "license"
require "shards/commands/install"
require "trigram"
require "wait_group"
require "yaml"

require "./commands/*"
require "./config"
require "./shard"
require "./shards/base"
require "./shards/install"
require "./template/*"

Colorize.on_tty_only!

module Geode
  VERSION = "0.1.0"

  BUILD_DATE = {% if flag?(:win32) %}
                 {{ `powershell.exe -NoProfile Get-Date -Format "yyyy-MM-dd"`.stringify.chomp }}
               {% else %}
                 {{ `date +%F`.stringify.chomp }}
               {% end %}

  BUILD_HASH    = {{ env("GEODE_HASH") || `git rev-parse HEAD`.stringify[0...8] }}
  HOST_TRIPLE   = {{ Crystal::DESCRIPTION.split("target:").last.strip }}
  HOST_PLATFORM = {{ flag?(:win32) ? "windows" : flag?(:darwin) ? "macos" : "linux" }}

  class CLI < Commands::Base
    def setup : Nil
      @name = "app"
      @header = %(#{"Geode".colorize.magenta} • #{"A Crystal Package Manager".colorize.light_magenta})

      add_command Commands::Version.new
      add_command Commands::Init.new
      # add_command Commands::Create.new
      add_command Commands::Install.new
      # add_command Commands::Add.new
      # add_command Commands::Check.new
      # add_command Commands::Update.new
      add_command Commands::Build.new
      add_command Commands::Watch.new
      # add_command Commands::Vendor.new
      add_command Commands::Remove.new
      # add_command Commands::Prune.new
      add_command Commands::List.new
      add_command Commands::Info.new
      add_command Commands::Licenses.new
      add_command Commands::Run.new
      add_command Commands::Config.new
      add_command Commands::Template.new
      add_command Commands::Help.new
    end

    def run(arguments : Cling::Arguments, options : Cling::Options) : Nil
      puts help_template
    end
  end
end
