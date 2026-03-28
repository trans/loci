module Loci
  module LSP
    class Provider < Loci::Provider
      @client : Client

      # Max time to wait for LSP server to finish indexing
      MAX_WAIT    = 10.0
      RETRY_DELAY = 0.25

      def initialize(command : String, root_dir : String)
        @root_dir = File.expand_path(root_dir)
        @client = Client.new(command, @root_dir)
        @client.initialize_handshake
      end

      def find_by_name(name : String) : Array(Loci::Symbol)
        results = wait_for_results { @client.workspace_symbol(name) }
        results.select { |si| si.name == name }.map { |si| to_loci_symbol(si) }
      end

      def search_by_name(pattern : String) : Array(Loci::Symbol)
        results = wait_for_results { @client.workspace_symbol(pattern) }
        results.map { |si| to_loci_symbol(si) }
      end

      def find_by_file(file : String) : Array(Loci::Symbol)
        results = wait_for_results { @client.document_symbol(file) }
        results.map { |si| to_loci_symbol(si) }
      end

      def find_by_kind(kind : String) : Array(Loci::Symbol)
        results = wait_for_results { @client.workspace_symbol("") }
        target_kind = kind.downcase
        results.select { |si| si.kind.to_human_string == target_kind }
               .map { |si| to_loci_symbol(si) }
      end

      def list_kinds : Array(String)
        SymbolKind.values.map(&.to_human_string).sort
      end

      def list_files : Array(String)
        # Not supported by LSP — ctags fallback handles this
        [] of String
      end

      def close : Nil
        @client.shutdown
      end

      # Retry query until results arrive or timeout — LSP servers need time to index
      private def wait_for_results(& : -> Array(SymbolInformation)) : Array(SymbolInformation)
        elapsed = 0.0
        loop do
          results = yield
          return results unless results.empty? && elapsed < MAX_WAIT
          return results if elapsed >= MAX_WAIT
          sleep RETRY_DELAY.seconds
          elapsed += RETRY_DELAY
        end
      end

      private def to_loci_symbol(si : SymbolInformation) : Loci::Symbol
        path = @client.uri_to_path(si.location.uri)
        # Make path relative to root_dir if possible
        if path.starts_with?(@root_dir)
          path = path.lchop(@root_dir).lchop("/")
        end

        Loci::Symbol.new(
          name: si.name,
          file: path,
          line: si.location.range.start_pos.line + 1, # LSP 0-indexed → 1-indexed
          kind: si.kind.to_human_string,
          scope: si.container_name
        )
      end
    end
  end
end
