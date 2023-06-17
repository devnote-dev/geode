#!/usr/bin/env crystal
require "./geode"

begin
  Geode::CLI.new.execute ARGV
rescue Geode::SystemExit
  exit 1
end
