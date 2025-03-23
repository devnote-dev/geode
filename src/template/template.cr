module Geode
  class Template
    include YAML::Serializable

    getter name : String
    getter summary : String
    getter author : String
    getter version : String
    getter source : String?
    getter files : Array(String) = [] of String
    @[YAML::Field(ignore: true)]
    property? shell_execute : Bool = false

    Dir.mkdir_p Config::TEMPLATES

    def self.list : Array({String, String})
      info = [] of {String, String}

      Dir.each_child(Config::TEMPLATES) do |name|
        next unless File.exists?(Config::TEMPLATES / name / "control.yml")
        next unless File.exists?(Config::TEMPLATES / name / "control.lua")

        template = load name
        info << {name, template.version}
      end

      info
    end

    def self.exists?(name : String) : Bool
      File.exists?(Config::TEMPLATES / name / "control.yml") &&
        File.exists?(Config::TEMPLATES / name / "control.lua")
    end

    def self.load(name : String) : self
      File.open(Config::TEMPLATES / name / "control.yml") do |file|
        Template.from_yaml file
      end
    end

    def self.remove(name : String) : Bool
      return false unless exists? name

      FileUtils.rm_rf Config::TEMPLATES / name
      true
    end

    def initialize(@name, @summary, @author, @source, @version, @files)
    end

    def install(source : Path) : Nil
      Dir.mkdir_p(dest = Config::TEMPLATES / @name)
      File.copy(source / "control.yml", dest / "control.yml")
      File.copy(source / "control.lua", dest / "control.lua")

      unless @files.empty?
        FileUtils.cp(@files.map { |f| source / f }, dest)
      end
    end

    def run_script(output : IO) : Nil
      script = File.read Config::TEMPLATES / name / "control.lua"
      runner = Runner.new script, output
      runner.load_standard_functions
    end

    def test_script(output : IO) : Nil
    end
  end
end
