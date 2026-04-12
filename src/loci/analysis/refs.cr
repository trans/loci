module Loci
  module Analysis
    class Refs
      COMMENT_PREFIX = /^\s*(?:#|\/\/|--|;|%|\/\*)/

      SKIP_DIRS = Set{".git", "node_modules", "vendor", "_build", "target",
                      "lib", "deps", "dist", "build", "__pycache__", ".venv",
                      "venv", ".bundle", "pkg"}

      record Reference,
        file : String,
        line : Int32,
        kind : String,
        snippet : String

      record Result,
        name : String,
        definitions : Array(Loci::Symbol),
        references : Array(Reference),
        total_matches : Int32

      def initialize(@root_dir : String, @client : Loci::Client)
      end

      def find(target : String, limit : Int32 = 200, include_defs : Bool = true) : Result
        name, scope = parse_target(target)
        defs = resolve_definitions(name, scope)

        if defs.empty?
          return Result.new(name: name, definitions: defs, references: [] of Reference, total_matches: 0)
        end

        def_sites = Set(String).new
        defs.each do |d|
          next unless d.line
          def_sites << "#{d.file}:#{d.line}"
        end

        files = collect_source_files
        pattern = /\b#{Regex.escape(name)}\b/
        raw_refs = [] of Reference

        files.each do |file|
          path = File.join(@root_dir, file)
          next unless File.exists?(path)

          next if binary_file?(path)

          begin
            lines = File.read_lines(path)
          rescue
            next
          end

          lines.each_with_index do |line_text, idx|
            line_num = idx + 1
            next unless pattern.matches?(line_text)
            next if def_sites.includes?("#{file}:#{line_num}")
            next if COMMENT_PREFIX.matches?(line_text)

            kind = classify(line_text, name, pattern)
            raw_refs << Reference.new(
              file: file,
              line: line_num,
              kind: kind,
              snippet: line_text.strip
            )
          end
        end

        def_files = defs.compact_map(&.file).to_set
        def_dirs = def_files.map { |f| File.dirname(f) }.to_set

        ranked = raw_refs.sort_by do |ref|
          tier = if def_files.includes?(ref.file)
                   0
                 elsif def_dirs.includes?(File.dirname(ref.file))
                   1
                 else
                   2
                 end
          {tier, ref.file, ref.line}
        end

        total = ranked.size
        all_refs = [] of Reference

        if include_defs
          defs.each do |d|
            snippet = read_line(d.file, d.line) || d.pattern || d.name
            all_refs << Reference.new(
              file: d.file,
              line: d.line || 0,
              kind: "def",
              snippet: snippet
            )
          end
        end

        all_refs.concat(ranked.first(limit))

        Result.new(
          name: name,
          definitions: defs,
          references: all_refs,
          total_matches: total
        )
      end

      private def parse_target(target : String) : {String, String?}
        if target.matches?(/^.+:\d+(:\d+)?$/)
          return resolve_position_target(target)
        end

        if idx = target.index('#')
          return {target[idx + 1..], target[0...idx]}
        end

        if target.includes?("::")
          parts = target.split("::")
          name = parts.pop
          scope = parts.join("::")
          return {name, scope.empty? ? nil : scope}
        end

        {target, nil}
      end

      private def resolve_position_target(target : String) : {String, String?}
        parts = target.split(":")
        file = parts[0]
        line_num = parts[1].to_i

        symbols = @client.find_by_file(file)
        best = symbols.min_by? do |s|
          if sl = s.line
            (sl - line_num).abs
          else
            Int32::MAX
          end
        end

        if best
          {best.name, best.scope}
        else
          raise "no symbol found near #{target}"
        end
      end

      private def resolve_definitions(name : String, scope : String?) : Array(Loci::Symbol)
        defs = @client.find_by_name(name)

        if scope && !defs.empty?
          filtered = defs.select do |d|
            d.scope && (d.scope == scope || d.scope.not_nil!.ends_with?(scope))
          end
          defs = filtered unless filtered.empty?
        end

        defs
      end

      private def classify(line_text : String, name : String, pattern : Regex) : String
        stripped = line_text.lstrip

        if stripped.starts_with?("def ") || stripped.starts_with?("private def ") ||
           stripped.starts_with?("abstract def ") || stripped.starts_with?("protected def ")
          return "def"
        end
        if stripped.starts_with?("class ") || stripped.starts_with?("module ") ||
           stripped.starts_with?("struct ") || stripped.starts_with?("enum ") ||
           stripped.starts_with?("abstract class ") || stripped.starts_with?("abstract struct ")
          return "def"
        end

        if match = pattern.match(line_text)
          before = match.pre_match.rstrip
          after_str = match.post_match.lstrip

          if before.ends_with?(".") || before.ends_with?("&.")
            return "call"
          end
          if after_str.starts_with?("(")
            return "call"
          end

          if after_str.starts_with?(".")
            return "ref"
          end

          if before.ends_with?("::")
            return "ref"
          end
          if before.ends_with?(":") || before.ends_with?("< ")
            return "ref"
          end
        end

        "?"
      end

      private def read_line(file : String, line_num : Int32?) : String?
        return nil unless line_num
        path = File.join(@root_dir, file)
        return nil unless File.exists?(path)
        lines = File.read_lines(path)
        idx = line_num - 1
        return nil if idx < 0 || idx >= lines.size
        lines[idx].strip
      end

      private def binary_file?(path : String) : Bool
        File.open(path, "rb") do |f|
          buf = Bytes.new(512)
          bytes_read = f.read(buf)
          buf[0, bytes_read].includes?(0_u8)
        end
      rescue
        true
      end

      private def collect_source_files : Array(String)
        files = [] of String
        walk_dir(@root_dir, files)
        files.sort!
      end

      private def walk_dir(dir : String, files : Array(String)) : Nil
        Dir.each_child(dir) do |entry|
          path = File.join(dir, entry)
          rel = Path[path].relative_to(@root_dir).to_s

          if Dir.exists?(path)
            next if SKIP_DIRS.includes?(entry)
            walk_dir(path, files)
          elsif File.file?(path)
            next if entry.starts_with?(".")
            next if entry == "tags"
            files << rel
          end
        end
      rescue File::AccessDeniedError
      end
    end
  end
end
