require "json"

module Loci
  module LSP
    enum SymbolKind
      def self.new(pull : JSON::PullParser) : self
        from_value(pull.read_int.to_i)
      end

      def to_json(json : JSON::Builder) : Nil
        json.number(value)
      end

      File          =  1
      Module        =  2
      Namespace     =  3
      Package       =  4
      Class         =  5
      Method        =  6
      Property      =  7
      Field         =  8
      Constructor   =  9
      Enum          = 10
      Interface     = 11
      Function      = 12
      Variable      = 13
      Constant      = 14
      String        = 15
      Number        = 16
      Boolean       = 17
      Array         = 18
      Object        = 19
      Key           = 20
      Null          = 21
      EnumMember    = 22
      Struct        = 23
      Event         = 24
      Operator      = 25
      TypeParameter = 26

      def to_human_string : ::String
        case self
        in File          then "file"
        in Module        then "module"
        in Namespace     then "namespace"
        in Package       then "package"
        in Class         then "class"
        in Method        then "method"
        in Property      then "property"
        in Field         then "field"
        in Constructor   then "constructor"
        in Enum          then "enum"
        in Interface     then "interface"
        in Function      then "function"
        in Variable      then "variable"
        in Constant      then "constant"
        in String        then "string"
        in Number        then "number"
        in Boolean       then "boolean"
        in Array         then "array"
        in Object        then "object"
        in Key           then "key"
        in Null          then "null"
        in EnumMember    then "enummember"
        in Struct        then "struct"
        in Event         then "event"
        in Operator      then "operator"
        in TypeParameter then "typeparameter"
        end
      end
    end

    struct Position
      include JSON::Serializable

      property line : Int32
      property character : Int32

      def initialize(@line, @character)
      end
    end

    struct Range
      include JSON::Serializable

      @[JSON::Field(key: "start")]
      property start_pos : Position

      @[JSON::Field(key: "end")]
      property end_pos : Position

      def initialize(@start_pos, @end_pos)
      end
    end

    struct Location
      include JSON::Serializable

      property uri : String
      property range : Range

      def initialize(@uri, @range)
      end
    end

    struct TextDocumentIdentifier
      include JSON::Serializable

      property uri : String

      def initialize(@uri)
      end
    end

    struct SymbolInformation
      include JSON::Serializable

      property name : String
      property kind : SymbolKind
      property location : Location

      @[JSON::Field(key: "containerName")]
      property container_name : String?

      def initialize(@name, @kind, @location, @container_name = nil)
      end
    end

    struct DocumentSymbol
      include JSON::Serializable

      property name : String
      property kind : SymbolKind
      property range : Range

      @[JSON::Field(key: "selectionRange")]
      property selection_range : Range

      property children : ::Array(DocumentSymbol)?
      property detail : String?

      def initialize(@name, @kind, @range, @selection_range, @children = nil, @detail = nil)
      end
    end

    struct ClientCapabilities
      include JSON::Serializable

      def initialize
      end
    end

    struct InitializeParams
      include JSON::Serializable

      @[JSON::Field(key: "processId")]
      property process_id : Int32?

      @[JSON::Field(key: "rootUri")]
      property root_uri : String?

      property capabilities : ClientCapabilities

      def initialize(@process_id, @root_uri, @capabilities)
      end
    end

    struct InitializeResult
      include JSON::Serializable

      property capabilities : JSON::Any

      def initialize(@capabilities)
      end
    end

    struct WorkspaceSymbolParams
      include JSON::Serializable

      property query : String

      def initialize(@query)
      end
    end

    struct DocumentSymbolParams
      include JSON::Serializable

      @[JSON::Field(key: "textDocument")]
      property text_document : TextDocumentIdentifier

      def initialize(@text_document)
      end
    end
  end
end
