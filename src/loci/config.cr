require "yaml"

module Loci
  class Config
    include YAML::Serializable

    property ctags : CtagsConfig = CtagsConfig.new
    property lsp : LSPConfig = LSPConfig.new
    property entries : Array(String) = [] of String

    def initialize
    end

    # Config file search order:
    #   1. .config/loci.yml  (XDG-style)
    #   2. .loci.yml         (convenience fallback)
    def self.load(dir : String) : Config
      [".config/loci.yml", ".loci.yml"].each do |name|
        path = File.join(dir, name)
        if File.exists?(path)
          return Config.from_yaml(File.read(path))
        end
      end
      Config.new
    end

    class CtagsConfig
      include YAML::Serializable

      property exclude : Array(String) = [] of String
      property flags : Array(String) = [] of String
      property file : String = "tags"
      property auto : Bool = true

      def initialize
      end
    end

    class LSPConfig
      include YAML::Serializable

      property command : String? = nil
      property root : String? = nil

      def initialize
      end
    end
  end
end
