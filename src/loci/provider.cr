module Loci
  abstract class Provider
    abstract def find_by_name(name : String) : Array(Symbol)
    abstract def search_by_name(pattern : String) : Array(Symbol)
    abstract def find_by_file(file : String) : Array(Symbol)
    abstract def find_by_kind(kind : String) : Array(Symbol)
    abstract def list_kinds : Array(String)
    abstract def list_files : Array(String)

    def close : Nil
    end
  end
end
