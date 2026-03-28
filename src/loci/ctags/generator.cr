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

        cmd = build_command(@config.ctags.file)
        result = Process.run(cmd, shell: true, chdir: @root_dir,
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

        scan_directory(@root_dir) do |mtime|
          if newest.nil? || mtime > newest.not_nil!
            newest = mtime
          end
        end

        newest
      end

      private def scan_directory(dir : String, &block : Time ->) : Nil
        Dir.each_child(dir) do |entry|
          path = File.join(dir, entry)
          # Use path relative to root for ignore matching
          rel_path = Path[path].relative_to(@root_dir).to_s

          if Dir.exists?(path)
            next if @ignore.ignores?(rel_path + "/")
            scan_directory(path, &block)
          elsif File.file?(path)
            next if entry == @config.ctags.file
            next if @ignore.ignores?(rel_path)
            yield File.info(path).modification_time
          end
        end
      rescue ex : File::AccessDeniedError
        # Skip directories we can't read
      end

      private def build_command(tags_path : String) : String
        parts = ["ctags", "-R"]
        parts << "-f" << tags_path

        # Use .gitignore patterns for exclusions if available
        gitignore_path = File.join(@root_dir, ".gitignore")
        if File.exists?(gitignore_path)
          # Extract top-level directory patterns from .gitignore for ctags --exclude
          File.each_line(gitignore_path) do |line|
            line = line.strip
            next if line.empty? || line.starts_with?("#") || line.starts_with?("!")
            # Strip leading/trailing slashes for ctags --exclude compatibility
            pattern = line.lstrip("/").chomp("/")
            next if pattern.empty?
            parts << "--exclude=#{pattern}"
          end
        else
          # Fallback: exclude common dirs that exist
          FALLBACK_EXCLUDE.each do |dir|
            if Dir.exists?(File.join(@root_dir, dir))
              parts << "--exclude=#{dir}"
            end
          end
        end

        # User-configured exclusions (always applied)
        @config.ctags.exclude.each do |dir|
          parts << "--exclude=#{dir}"
        end

        # User-configured extra flags
        @config.ctags.flags.each do |flag|
          parts << flag
        end

        parts << "."
        parts.join(" ")
      end
    end
  end
end
