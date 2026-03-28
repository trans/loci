require "option_parser"

module Loci
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

  class CLI
    def self.run(args : Array(String))
      tags_file_override = nil
      lsp_command = nil
      root_dir = Dir.current
      no_auto = false
      command = nil
      name = nil
      file = nil
      kind = nil
      pattern = nil

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: loci [options]"

        opts.on("--tags=FILE", "Path to tags file (default: tags)") { |f| tags_file_override = f }
        opts.on("--lsp=COMMAND", "LSP server command (e.g. \"rust-analyzer\")") { |c| lsp_command = c }
        opts.on("--root=DIR", "Project root directory (default: current)") { |d| root_dir = d }
        opts.on("--no-auto", "Disable auto-generation of tags") { no_auto = true }
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

      # Load config
      config = Config.load(root_dir)

      # CLI flags override config
      tags_file = if override = tags_file_override
                    override
                  else
                    config.ctags.file
                  end
      lsp_command ||= config.lsp.command
      root_dir = config.lsp.root || root_dir

      # Build provider chain — LSP first, ctags second
      providers = [] of Provider

      if cmd = lsp_command
        begin
          providers << LSP::Provider.new(cmd, root_dir)
        rescue ex
          STDERR.puts "Warning: LSP server failed to start: #{ex.message}"
        end
      end

      # Auto-generate/refresh ctags if enabled
      auto = config.ctags.auto && !no_auto
      if auto && Ctags::Generator.ctags_available?
        begin
          generator = Ctags::Generator.new(root_dir, config)
          generator.ensure_fresh
        rescue ex
          STDERR.puts "Warning: ctags generation failed: #{ex.message}"
        end
      end

      tags_path = File.join(root_dir, tags_file)
      if File.exists?(tags_path)
        providers << Ctags::Provider.new(tags_path)
      end

      if providers.empty?
        STDERR.puts "Error: No providers available. Provide --lsp, a tags file, or install ctags."
        exit 1
      end

      client = Client.new(providers)

      case command
      when :find_name
        display_results(client.find_by_name(name.not_nil!))
      when :search
        display_results(client.search_by_name(pattern.not_nil!))
      when :list_file
        display_results(client.find_by_file(file.not_nil!))
      when :filter_kind
        display_results(client.find_by_kind(kind.not_nil!))
      when :list_kinds
        client.list_kinds.each { |k| puts k }
      when :list_files
        client.list_files.each { |f| puts f }
      else
        STDERR.puts "Error: No command specified. Use --help for usage."
        exit 1
      end
    end

    private def self.display_results(results : Array(Symbol))
      if results.empty?
        puts "No results found."
      else
        results.each { |sym| puts sym }
      end
    end
  end
end
