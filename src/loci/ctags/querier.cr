module Loci
  module Ctags
    class Querier
      def initialize(@tags : Array(Tag))
      end

      def find_by_name(name : String) : Array(Tag)
        @tags.select { |tag| tag.name == name }
      end

      def search_by_name(pattern : String) : Array(Tag)
        regex = Regex.new(pattern, Regex::Options::IGNORE_CASE)
        @tags.select { |tag| tag.name =~ regex }
      end

      def find_by_file(file : String) : Array(Tag)
        @tags.select { |tag| tag.file == file }
      end

      def find_by_kind(kind : String) : Array(Tag)
        @tags.select { |tag| tag.kind == kind }
      end

      def list_kinds : Array(String)
        kind_info = {} of String => String

        @tags.each do |tag|
          next unless tag.kind
          kind = tag.kind.not_nil!

          if tag.kind_map
            ext = File.extname(tag.file).lstrip('.')
            language = Loci.infer_language(ext)
            key = "#{language}:#{kind}"

            if desc = tag.kind_map.try &.[key]?
              kind_info[key] = "#{kind}\t#{desc.name} (#{desc.language})"
            elsif !kind_info.has_key?(key)
              kind_info[key] = kind
            end
          else
            simple_key = "unknown:#{kind}"
            kind_info[simple_key] = kind unless kind_info.has_key?(simple_key)
          end
        end

        kind_info.values.sort
      end

      def list_files : Array(String)
        @tags.map(&.file).uniq.sort
      end
    end
  end
end
