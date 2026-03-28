module Loci
  # Unified code symbol returned by all providers
  struct Symbol
    property name : String
    property file : String
    property line : Int32?
    property kind : String?
    property scope : String?
    property signature : String?
    property pattern : String?

    def initialize(@name, @file, @line = nil, @kind = nil, @scope = nil,
                   @signature = nil, @pattern = nil)
    end

    def to_s(io : IO)
      io << name << "\t" << file
      io << "\tline:" << line if line
      io << "\tkind:" << kind if kind
      io << "\tscope:" << scope if scope
      io << "\t" << pattern if pattern
    end
  end
end
