module Loci
  module Analysis
    # Filters out dead-code results that are false positives from
    # `crystal tool unreachable` because they're invoked via macro-generated
    # JSON::Serializable deserialization code the compiler's static call
    # graph can't see through.
    #
    # Applies only to methods named `initialize`, `to_json`, or `from_json`
    # inside classes that `include JSON::Serializable`.
    class JsonSerializableFilter
      REFLECTION_METHODS   = {"initialize", "to_json", "from_json"}
      ENUM_JSON_METHODS    = {"to_json", "from_json", "new"}

      def initialize(@root_dir : String)
        @source_cache = {} of String => Array(String)
      end

      def filter(results : Array(Dead::Result)) : Array(Dead::Result)
        results.reject { |r| suppressed?(r) }
      end

      private def suppressed?(result : Dead::Result) : Bool
        lines = source_lines(result.file)
        return false if lines.empty?

        enclosing = find_enclosing(lines, result.line)
        return false unless enclosing

        type, _indent = enclosing
        case type
        when :enum
          ENUM_JSON_METHODS.includes?(result.name)
        when :class
          REFLECTION_METHODS.includes?(result.name) &&
            has_json_serializable?(lines, result.line)
        else
          false
        end
      end

      private def source_lines(file : String) : Array(String)
        @source_cache[file] ||= begin
          path = File.join(@root_dir, file)
          File.exists?(path) ? File.read(path).lines : [] of String
        end
      end

      # Walk backward from the method line to find the enclosing type.
      # Returns {:class | :enum, indent} or nil.
      private def find_enclosing(lines : Array(String), method_line : Int32) : {::Symbol, Int32}?
        method_idx = method_line - 1
        return nil if method_idx < 0 || method_idx >= lines.size

        method_indent = leading_spaces(lines[method_idx])

        (method_idx - 1).downto(0) do |i|
          line = lines[i]
          stripped = line.lstrip
          next if stripped.empty? || stripped.starts_with?("#")

          indent = leading_spaces(line)
          next unless indent < method_indent

          if stripped.matches?(/^enum\s+/)
            return {:enum, indent}
          elsif stripped.matches?(/^(?:abstract\s+)?(?:class|struct)\s+/)
            return {:class, indent}
          end
        end

        nil
      end

      # Scan the enclosing class body for `include JSON::Serializable`.
      private def has_json_serializable?(lines : Array(String), method_line : Int32) : Bool
        method_idx = method_line - 1
        return false if method_idx < 0 || method_idx >= lines.size

        method_indent = leading_spaces(lines[method_idx])

        # Find the enclosing class line and its indent
        enclosing_idx = nil
        enclosing_indent = 0
        (method_idx - 1).downto(0) do |i|
          line = lines[i]
          stripped = line.lstrip
          next if stripped.empty? || stripped.starts_with?("#")

          indent = leading_spaces(line)
          next unless indent < method_indent

          if stripped.matches?(/^(?:abstract\s+)?(?:class|struct)\s+/)
            enclosing_idx = i
            enclosing_indent = indent
            break
          end
        end

        return false unless enclosing_idx

        # Scan forward within the class body
        i = enclosing_idx + 1
        while i < lines.size
          line = lines[i]
          stripped = line.lstrip

          if !stripped.empty? && !stripped.starts_with?("#")
            indent = leading_spaces(line)

            if stripped == "end" && indent == enclosing_indent
              return false
            end

            if stripped.matches?(/^include\s+(?:::)?JSON::Serializable/)
              return true
            end
          end

          i += 1
        end

        false
      end

      private def leading_spaces(line : String) : Int32
        count = 0
        line.each_char do |c|
          break unless c == ' '
          count += 1
        end
        count
      end
    end
  end
end
