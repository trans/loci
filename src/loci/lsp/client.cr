module Loci
  module LSP
    class Client
      @transport : Transport

      def initialize(command : String, @root_dir : String)
        @transport = Transport.new(command)
      end

      # Perform the LSP initialize handshake
      def initialize_handshake : Nil
        params = InitializeParams.new(
          process_id: Process.pid.to_i32,
          root_uri: path_to_uri(@root_dir),
          capabilities: ClientCapabilities.new
        )
        @transport.request("initialize", params)
        @transport.notify("initialized", ClientCapabilities.new)
      end

      # workspace/symbol
      def workspace_symbol(query : String) : Array(SymbolInformation)
        params = WorkspaceSymbolParams.new(query: query)
        result = @transport.request("workspace/symbol", params)
        return [] of SymbolInformation if result.raw.nil?
        Array(SymbolInformation).from_json(result.to_json)
      end

      # textDocument/documentSymbol — handles both flat and hierarchical responses
      def document_symbol(file_path : String) : Array(SymbolInformation)
        uri = path_to_uri(file_path)
        params = DocumentSymbolParams.new(
          text_document: TextDocumentIdentifier.new(uri: uri)
        )
        result = @transport.request("textDocument/documentSymbol", params)
        return [] of SymbolInformation if result.raw.nil?

        arr = result.as_a
        return [] of SymbolInformation if arr.empty?

        # Detect form: SymbolInformation has "location", DocumentSymbol has "range" + "selectionRange"
        if arr[0]["location"]?
          Array(SymbolInformation).from_json(result.to_json)
        else
          doc_symbols = Array(DocumentSymbol).from_json(result.to_json)
          flatten_document_symbols(doc_symbols, uri)
        end
      end

      def shutdown : Nil
        begin
          @transport.request("shutdown")
          @transport.notify("exit")
        rescue
          # Server may already be dead
        end
        @transport.close
      end

      def path_to_uri(path : String) : String
        abs = File.expand_path(path)
        "file://#{abs}"
      end

      def uri_to_path(uri : String) : String
        uri.sub("file://", "")
      end

      private def flatten_document_symbols(symbols : Array(DocumentSymbol), uri : String,
                                           container : String? = nil) : Array(SymbolInformation)
        result = [] of SymbolInformation
        symbols.each do |sym|
          location = Location.new(uri: uri, range: sym.range)
          info = SymbolInformation.new(
            name: sym.name,
            kind: sym.kind,
            location: location,
            container_name: container
          )
          result << info
          if children = sym.children
            result.concat(flatten_document_symbols(children, uri, sym.name))
          end
        end
        result
      end
    end
  end
end
