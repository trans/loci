module Loci
  module Ctags
    struct KindDescription
      property language : String
      property letter : String
      property name : String
      property description : String

      def initialize(@language, @letter, @name, @description)
      end
    end
  end
end
