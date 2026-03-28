module Loci
  class Client
    def initialize(@providers : Array(Provider))
    end

    def find_by_name(name : String) : Array(Symbol)
      try_providers(&.find_by_name(name))
    end

    def search_by_name(pattern : String) : Array(Symbol)
      try_providers(&.search_by_name(pattern))
    end

    def find_by_file(file : String) : Array(Symbol)
      try_providers(&.find_by_file(file))
    end

    def find_by_kind(kind : String) : Array(Symbol)
      try_providers(&.find_by_kind(kind))
    end

    def list_kinds : Array(String)
      try_string_providers(&.list_kinds)
    end

    def list_files : Array(String)
      try_string_providers(&.list_files)
    end

    private def try_providers(& : Provider -> Array(Symbol)) : Array(Symbol)
      @providers.each do |provider|
        begin
          results = yield provider
          return results unless results.empty?
        rescue
          next
        end
      end
      [] of Symbol
    end

    private def try_string_providers(& : Provider -> Array(String)) : Array(String)
      @providers.each do |provider|
        begin
          results = yield provider
          return results unless results.empty?
        rescue
          next
        end
      end
      [] of String
    end
  end
end
