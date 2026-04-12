module Loci
  module Analysis
    module Dead
      record Result,
        file : String,
        line : Int32,
        col : Int32,
        scope : String?,
        name : String,
        kind : String,
        size : Int32

      # Analyze entry points for dead code, dispatching per extension.
      # Returns aggregated results across all entries.
      def self.analyze(entries : Array(String), root_dir : String) : Array(Result)
        results = [] of Result
        entries.each do |entry|
          case File.extname(entry)
          when ".cr"
            results.concat(analyze_crystal(entry, root_dir))
          end
        end
        results
      end

      # Shell out to `crystal tool unreachable` and parse the output.
      def self.analyze_crystal(entry : String, root_dir : String) : Array(Result)
        output = IO::Memory.new
        error = IO::Memory.new
        status = Process.run("crystal", ["tool", "unreachable", entry],
          chdir: root_dir,
          output: output,
          error: error)
        unless status.success?
          raise "crystal tool unreachable failed: #{error.to_s.strip}"
        end
        parse_crystal_output(output.to_s)
      end

      # Parse tab-separated output:
      #   src/foo.cr:38:7\tMyApp::Foo#bar\t6 lines
      def self.parse_crystal_output(text : String) : Array(Result)
        results = [] of Result
        text.each_line do |raw|
          line = raw.chomp
          next if line.empty?

          parts = line.split('\t')
          next unless parts.size == 3

          location = parts[0]
          qualified = parts[1]
          size_str = parts[2]

          loc_match = location.match(/^(.+):(\d+):(\d+)$/)
          next unless loc_match
          file = loc_match[1]
          line_num = loc_match[2].to_i
          col = loc_match[3].to_i

          scope, name, kind = parse_qualified(qualified)
          size = size_str.strip.split(" ").first.to_i? || 0

          results << Result.new(
            file: file,
            line: line_num,
            col: col,
            scope: scope,
            name: name,
            kind: kind,
            size: size
          )
        end
        results
      end

      # Split "Scope::Chain#method" → {"Scope::Chain", "method", "method"}
      # Split "Scope::Chain.method" → {"Scope::Chain", "method", "class_method"}
      # Split "top_level"            → {nil,           "top_level", "def"}
      def self.parse_qualified(qualified : String) : {String?, String, String}
        if idx = qualified.index('#')
          {qualified[0...idx], qualified[idx + 1..], "method"}
        elsif idx = qualified.rindex('.')
          {qualified[0...idx], qualified[idx + 1..], "class_method"}
        else
          {nil, qualified, "def"}
        end
      end
    end
  end
end
