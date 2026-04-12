require "ignore"

module Loci
  module Ctags
    class Generator
      # Fallback exclusions when no .gitignore exists
      FALLBACK_EXCLUDE = [
        ".git",
        "node_modules",
        "vendor",
        "_build",
        "target",
        "lib",
        "deps",
        "dist",
        "build",
        "__pycache__",
        ".venv",
        "venv",
        ".bundle",
        "pkg",
      ]

      @ignore : Ignore::Matcher

      def initialize(@root_dir : String, @config : Config)
        @ignore = load_ignore
      end

      # Generate tags file, return its path
      def generate : String
        tags_path = File.join(@root_dir, @config.ctags.file)

        unless self.class.ctags_available?
          raise "ctags not found in PATH"
        end

        source_files = collect_source_files
        if source_files.empty?
          File.write(tags_path, "")
          return tags_path
        end

        args = build_args(@config.ctags.file)
        input = IO::Memory.new(source_files.join('\n') + "\n")
        result = Process.run("ctags", args: args, input: input, chdir: @root_dir,
          error: Process::Redirect::Pipe)

        unless result.success?
          raise "ctags failed (exit #{result.exit_code})"
        end

        tags_path
      end

      # Generate if missing or stale, return tags path
      def ensure_fresh : String
        tags_path = File.join(@root_dir, @config.ctags.file)

        if File.exists?(tags_path) && !stale?(tags_path)
          tags_path
        else
          generate
        end
      end

      # Check if tags file is older than any source file
      def stale?(tags_path : String) : Bool
        tags_mtime = File.info(tags_path).modification_time
        newest_source = newest_source_mtime
        return false unless newest_source
        newest_source > tags_mtime
      end

      def self.ctags_available? : Bool
        result = Process.run("which ctags", shell: true,
          output: Process::Redirect::Close,
          error: Process::Redirect::Close)
        result.success?
      end

      private def load_ignore : Ignore::Matcher
        gitignore_path = File.join(@root_dir, ".gitignore")
        if File.exists?(gitignore_path)
          # Load all .gitignore files from the project tree
          Ignore.root(@root_dir)
        else
          # Fall back to common exclusion patterns
          matcher = Ignore::Matcher.new
          FALLBACK_EXCLUDE.each { |dir| matcher.add(dir) }
          matcher
        end
      end

      private def newest_source_mtime : Time?
        newest = nil

        each_source_file(@root_dir) do |_, mtime|
          if newest.nil? || mtime > newest.not_nil!
            newest = mtime
          end
        end

        newest
      end

      private def collect_source_files : Array(String)
        files = [] of String

        each_source_file(@root_dir) do |rel_path, _|
          files << rel_path
        end

        files.sort!
      end

      private def each_source_file(dir : String, &block : String, Time ->) : Nil
        Dir.each_child(dir) do |entry|
          path = File.join(dir, entry)
          # Use path relative to root for ignore matching
          rel_path = Path[path].relative_to(@root_dir).to_s

          if Dir.exists?(path)
            next if @ignore.ignores?(rel_path + "/")
            each_source_file(path, &block)
          elsif File.file?(path)
            next if entry == @config.ctags.file
            next if @ignore.ignores?(rel_path)
            yield rel_path, File.info(path).modification_time
          end
        end
      rescue ex : File::AccessDeniedError
        # Skip directories we can't read
      end

      private def build_args(tags_path : String) : Array(String)
        args = ["-f", tags_path, "--fields=+n", "-L", "-"]

        # User-configured extra flags
        @config.ctags.flags.each do |flag|
          args << flag
        end

        args
      end
    end
  end
end
