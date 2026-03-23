#!/usr/bin/env crystal

require "option_parser"

module Loci
  VERSION = "0.1.0"

  # Infer programming language from file extension
  def self.infer_language(ext : String) : String
    case ext
    when "rb" then "Ruby"
    when "py" then "Python"
    when "js" then "JavaScript"
    when "ts" then "TypeScript"
    when "ex", "exs" then "Elixir"
    when "cr" then "Crystal"
    when "go" then "Go"
    when "rs" then "Rust"
    when "c", "h" then "C"
    when "cpp", "cc", "cxx", "hpp" then "C++"
    when "java" then "Java"
    else ext.capitalize
    end
  end

  # Kind metadata from tags file headers
  struct KindDescription
    property language : String
    property letter : String
    property name : String
    property description : String

    def initialize(@language, @letter, @name, @description)
    end
  end

  # Represents a single tag entry from a ctags file
  struct Tag
    property name : String
    property file : String
    property pattern : String
    property kind : String?
    property scope : String?
    property signature : String?
    property line : Int32?
    property kind_map : Hash(String, KindDescription)?

    def initialize(@name, @file, @pattern, @kind = nil, @scope = nil, @signature = nil, @line = nil, @kind_map = nil)
    end

    def to_s(io : IO)
      io << name << "\t" << file

      # Show line number right after file path (most useful for navigation)
      io << "\t" << "line:" << line if line

      if kind
        # Try to resolve kind using metadata
        if kind_map && (desc = resolve_kind_description)
          io << "\t" << "kind:" << desc.name << " (" << desc.language << ")"
        else
          io << "\t" << "kind:" << kind
        end
      end

      io << "\t" << "scope:" << scope if scope

      # Pattern at the end (less important for human readability)
      io << "\t" << pattern
    end

    private def resolve_kind_description : KindDescription?
      return nil unless kind_map && kind

      # Extract language from file extension
      ext = File.extname(file).lstrip('.')
      language = Loci.infer_language(ext)

      # Look up kind description
      kind_map.try &.["#{language}:#{kind}"]?
    end
  end

  # Parser for ctags file format
  class Parser
    def initialize(@tags_file : String)
    end

    def parse : Array(Tag)
      tags = [] of Tag
      kind_map = {} of String => KindDescription

      # First pass: parse metadata headers
      File.each_line(@tags_file) do |line|
        if line.starts_with?("!_TAG_KIND_DESCRIPTION!")
          if desc = parse_kind_description(line)
            # Map both the letter (m) and the full name (module)
            kind_map["#{desc.language}:#{desc.letter}"] = desc
            kind_map["#{desc.language}:#{desc.name}"] = desc
          end
        end
      end

      # Second pass: parse tags
      File.each_line(@tags_file) do |line|
        # Skip comments and empty lines
        next if line.starts_with?("!") || line.strip.empty?

        if tag = parse_line(line)
          tag.kind_map = kind_map unless kind_map.empty?
          tags << tag
        end
      end

      tags
    end

    private def parse_kind_description(line : String) : KindDescription?
      # Format: !_TAG_KIND_DESCRIPTION!{LANGUAGE}\t{LETTER},{NAME}\t/{DESCRIPTION}/
      parts = line.split("\t")
      return nil if parts.size < 3

      # Extract language from first part: !_TAG_KIND_DESCRIPTION!Ruby
      language_part = parts[0]
      language = language_part.split("!").last
      return nil unless language

      # Extract letter and name: f,method
      kind_part = parts[1]
      letter, name = kind_part.split(",", 2)
      return nil unless letter && name

      # Extract description: /methods/
      desc_part = parts[2]
      description = desc_part.gsub(/^\/|\/\s*$/, "")

      KindDescription.new(language, letter, name, description)
    end

    private def parse_line(line : String) : Tag?
      # Tags format: NAME<Tab>FILE<Tab>EX_COMMAND;"<Tab>EXTENSIONS
      parts = line.split("\t")
      return nil if parts.size < 3

      name = parts[0]
      file = parts[1]
      pattern = parts[2]

      # Parse extension fields (kind, scope, signature, line, etc.)
      kind = nil
      scope = nil
      signature = nil
      line_num = nil

      parts[3..].each do |ext|
        case ext
        when .starts_with?("kind:")
          kind = ext[5..]
        when .starts_with?("scope:")
          scope = ext[6..]
        when .starts_with?("signature:")
          signature = ext[10..]
        when .starts_with?("line:")
          line_num = ext[5..].to_i?
        when .starts_with?("module:")
          # Scope field in module:Name format
          scope = ext[7..]
        when .starts_with?("class:")
          # Scope field in class:Name format
          scope = ext[6..]
        when /^[a-z]$/
          # Single letter kind (old format)
          kind = ext if kind.nil?
        when /^[a-z]+$/
          # Standalone kind name (--fields=+K format): module, function, class, etc.
          kind = ext if kind.nil?
        end
      end

      Tag.new(name, file, pattern, kind, scope, signature, line_num)
    end
  end

  # Query operations on parsed tags
  class Querier
    def initialize(@tags : Array(Tag))
    end

    # Find tags by exact name match
    def find_by_name(name : String) : Array(Tag)
      @tags.select { |tag| tag.name == name }
    end

    # Find tags by name pattern (case-insensitive)
    def search_by_name(pattern : String) : Array(Tag)
      regex = Regex.new(pattern, Regex::Options::IGNORE_CASE)
      @tags.select { |tag| tag.name =~ regex }
    end

    # List all tags in a specific file
    def find_by_file(file : String) : Array(Tag)
      @tags.select { |tag| tag.file == file }
    end

    # Filter tags by kind (f=function, c=class, m=method, etc.)
    def find_by_kind(kind : String) : Array(Tag)
      @tags.select { |tag| tag.kind == kind }
    end

    # List all unique tag kinds with descriptions
    def list_kinds : Array(String)
      # Collect unique (kind, language) pairs with descriptions
      # Key is "language:kind" to handle same letter meaning different things
      kind_info = {} of String => String

      @tags.each do |tag|
        next unless tag.kind
        kind = tag.kind.not_nil!

        # Try to get full description
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
          # No metadata available, just show the letter
          simple_key = "unknown:#{kind}"
          kind_info[simple_key] = kind unless kind_info.has_key?(simple_key)
        end
      end

      kind_info.values.sort
    end

    # List all unique files with tags
    def list_files : Array(String)
      @tags.map(&.file).uniq.sort
    end
  end

  # CLI interface
  class CLI
    def self.run(args : Array(String))
      tags_file = "tags"
      command = nil
      name = nil
      file = nil
      kind = nil
      pattern = nil

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: loci [options]"

        opts.on("--tags=FILE", "Path to tags file (default: tags)") { |f| tags_file = f }
        opts.on("--name=NAME", "Find exact tag by name") { |n| name = n; command = :find_name }
        opts.on("--search=PATTERN", "Search tags by pattern") { |p| pattern = p; command = :search }
        opts.on("--file=FILE", "List tags in file") { |f| file = f; command = :list_file }
        opts.on("--kind=KIND", "Filter by kind (f, c, m, etc.)") { |k| kind = k; command = :filter_kind }
        opts.on("--list-kinds", "List all tag kinds") { command = :list_kinds }
        opts.on("--list-files", "List all files with tags") { command = :list_files }
        opts.on("-h", "--help", "Show help") do
          puts opts
          exit
        end
        opts.on("-v", "--version", "Show version") do
          puts "loci #{VERSION}"
          exit
        end
      end

      parser.parse(args)

      unless File.exists?(tags_file)
        STDERR.puts "Error: Tags file not found: #{tags_file}"
        exit 1
      end

      # Parse tags file
      tags = Parser.new(tags_file).parse
      querier = Querier.new(tags)

      # Execute command
      case command
      when :find_name
        results = querier.find_by_name(name.not_nil!)
        display_results(results)
      when :search
        results = querier.search_by_name(pattern.not_nil!)
        display_results(results)
      when :list_file
        results = querier.find_by_file(file.not_nil!)
        display_results(results)
      when :filter_kind
        results = querier.find_by_kind(kind.not_nil!)
        display_results(results)
      when :list_kinds
        querier.list_kinds.each { |k| puts k }
      when :list_files
        querier.list_files.each { |f| puts f }
      else
        STDERR.puts "Error: No command specified. Use --help for usage."
        exit 1
      end
    end

    private def self.display_results(results : Array(Tag))
      if results.empty?
        puts "No results found."
      else
        results.each { |tag| puts tag }
      end
    end
  end
end

# Only run CLI if this file is being executed directly (not required/spec'd)
# Crystal's PROGRAM_NAME is the path to the executable when compiled
# When required by specs, this won't match
if PROGRAM_NAME.includes?("loci") && !PROGRAM_NAME.includes?("crystal-run-spec")
  Loci::CLI.run(ARGV)
end
