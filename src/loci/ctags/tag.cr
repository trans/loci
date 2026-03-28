module Loci
  module Ctags
    struct Tag
      property name : String
      property file : String
      property pattern : String
      property kind : String?
      property scope : String?
      property signature : String?
      property line : Int32?
      property kind_map : Hash(String, KindDescription)?

      def initialize(@name, @file, @pattern, @kind = nil, @scope = nil,
                     @signature = nil, @line = nil, @kind_map = nil)
      end

      # Convert to unified Symbol, resolving kind letters to full names
      def to_symbol : Loci::Symbol
        resolved_kind = resolve_kind_name
        Loci::Symbol.new(
          name: @name,
          file: @file,
          line: @line,
          kind: resolved_kind || @kind,
          scope: @scope,
          signature: @signature,
          pattern: @pattern
        )
      end

      def to_s(io : IO)
        io << name << "\t" << file
        io << "\t" << "line:" << line if line

        if kind
          if kind_map && (desc = resolve_kind_description)
            io << "\t" << "kind:" << desc.name << " (" << desc.language << ")"
          else
            io << "\t" << "kind:" << kind
          end
        end

        io << "\t" << "scope:" << scope if scope
        io << "\t" << pattern
      end

      private def resolve_kind_name : String?
        return nil unless kind && kind_map
        ext = File.extname(file).lstrip('.')
        language = Loci.infer_language(ext)
        if desc = kind_map.try &.["#{language}:#{kind}"]?
          desc.name
        else
          nil
        end
      end

      private def resolve_kind_description : KindDescription?
        return nil unless kind_map && kind
        ext = File.extname(file).lstrip('.')
        language = Loci.infer_language(ext)
        kind_map.try &.["#{language}:#{kind}"]?
      end
    end
  end
end
