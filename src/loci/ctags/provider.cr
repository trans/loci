module Loci
  module Ctags
    class Provider < Loci::Provider
      def initialize(tags_file : String)
        tags = Parser.new(tags_file).parse
        @querier = Querier.new(tags)
      end

      def find_by_name(name : String) : Array(Loci::Symbol)
        @querier.find_by_name(name).map(&.to_symbol)
      end

      def search_by_name(pattern : String) : Array(Loci::Symbol)
        @querier.search_by_name(pattern).map(&.to_symbol)
      end

      def find_by_file(file : String) : Array(Loci::Symbol)
        @querier.find_by_file(file).map(&.to_symbol)
      end

      def find_by_kind(kind : String) : Array(Loci::Symbol)
        @querier.find_by_kind(kind).map(&.to_symbol)
      end

      def list_kinds : Array(String)
        @querier.list_kinds
      end

      def list_files : Array(String)
        @querier.list_files
      end
    end
  end
end
