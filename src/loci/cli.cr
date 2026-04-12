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
      force_tags = false
      command = nil
      name = nil
      file = nil
      kind = nil
      pattern = nil
      refs_target = nil
      refs_no_defs = false
      refs_limit = 200

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: loci [options]"

        opts.on("--tags=FILE", "Path to tags file (default: tags)") { |f| tags_file_override = f }
        opts.on("--lsp=COMMAND", "LSP server command (e.g. \"rust-analyzer\")") { |c| lsp_command = c }
        opts.on("--root=DIR", "Project root directory (default: current)") { |d| root_dir = d }
        opts.on("--no-auto", "Disable auto-generation of tags") { no_auto = true }
        opts.on("--force", "Regenerate tags before querying") { force_tags = true }
        opts.on("--name=NAME", "Find exact tag by name") { |n| name = n; command = :find_name }
        opts.on("--search=PATTERN", "Search tags by pattern") { |p| pattern = p; command = :search }
        opts.on("--file=FILE", "List tags in file") { |f| file = f; command = :list_file }
        opts.on("--kind=KIND", "Filter by kind (f, c, m, etc.)") { |k| kind = k; command = :filter_kind }
        opts.on("--list-kinds", "List all tag kinds") { command = :list_kinds }
        opts.on("--list-files", "List all files with tags") { command = :list_files }
        opts.on("--dead", "Report unreachable code via compiler-backed analysis") { command = :dead }
        opts.on("--refs=TARGET", "Find references to a symbol (name, Scope#name, file:line)") { |t| refs_target = t; command = :refs }
        opts.on("--no-defs", "Exclude definitions from --refs output") { refs_no_defs = true }
        opts.on("--limit=N", "Max results for --refs (default: 200)") { |n| refs_limit = n.to_i }
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

      # --dead bypasses the provider chain entirely; it uses entries + crystal tool.
      if command == :dead
        run_dead(config, root_dir)
        return
      end

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
          force_tags ? generator.generate : generator.ensure_fresh
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
      exit_status = 0

      begin
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
        when :refs
          run_refs(client, root_dir, refs_target.not_nil!, refs_limit, !refs_no_defs)
        else
          STDERR.puts "Error: No command specified. Use --help for usage."
          exit_status = 1
        end
      ensure
        client.close
      end

      exit exit_status if exit_status != 0
    end

    private def self.display_results(results : Array(Symbol))
      if results.empty?
        puts "No results found."
      else
        results.each { |sym| puts sym }
      end
    end

    private def self.run_refs(client : Client, root_dir : String, target : String,
                                limit : Int32, include_defs : Bool)
      finder = Analysis::Refs.new(root_dir, client)
      result = finder.find(target, limit: limit, include_defs: include_defs)

      if result.definitions.empty?
        STDERR.puts "No definition found for '#{result.name}'."
        return
      end

      def_count = result.definitions.size
      ambiguous = def_count > 1 ? " across #{def_count} definitions (ambiguous)" : ""
      truncated = result.total_matches > limit ? ", truncated to #{limit} of ~#{result.total_matches}" : ""

      puts "# #{result.references.size} references to `#{result.name}` via ctags+grep (heuristic#{ambiguous}#{truncated})"
      result.references.each do |ref|
        puts "#{ref.file}:#{ref.line}:#{ref.kind}: #{ref.snippet}"
      end
    end

    private def self.run_dead(config : Config, root_dir : String)
      entries = resolve_entries(config, root_dir)

      raw = [] of Analysis::Dead::Result
      entries.each do |entry|
        begin
          raw.concat(Analysis::Dead.analyze([entry], root_dir))
        rescue ex
          STDERR.puts "Warning: dead-code analysis failed for #{entry}: #{ex.message}"
        end
      end

      filter = Analysis::JsonSerializableFilter.new(root_dir)
      results = filter.filter(raw)

      source = "via `crystal tool unreachable` (authoritative)"
      filtered = raw.size - results.size
      suffix = filtered > 0 ? ", #{filtered} JSON::Serializable false-positive#{filtered == 1 ? "" : "s"} filtered" : ""

      puts "# #{results.size} dead symbol#{results.size == 1 ? "" : "s"} #{source}#{suffix}"
      results.each { |r| puts format_dead(r) }
    end

    private def self.resolve_entries(config : Config, root_dir : String) : Array(String)
      return config.entries unless config.entries.empty?

      bin_dir = File.join(root_dir, "bin")
      if Dir.exists?(bin_dir)
        cr_files = Dir.children(bin_dir).select(&.ends_with?(".cr")).sort
        if cr_files.size == 1
          return ["bin/#{cr_files.first}"]
        end
      end

      STDERR.puts "Error: no entries configured. Set `entries:` in .loci.yml or place a single .cr file in bin/."
      exit 1
    end

    private def self.format_dead(result : Analysis::Dead::Result) : String
      scope = result.scope || ""
      "#{result.file}:#{result.line}:#{result.kind}:#{scope}: #{result.name}"
    end
  end
end
