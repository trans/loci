module Loci
  module Ctags
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
              kind_map["#{desc.language}:#{desc.letter}"] = desc
              kind_map["#{desc.language}:#{desc.name}"] = desc
            end
          end
        end

        # Second pass: parse tags
        File.each_line(@tags_file) do |line|
          next if line.starts_with?("!") || line.strip.empty?

          if tag = parse_line(line)
            tag.kind_map = kind_map unless kind_map.empty?
            tags << tag
          end
        end

        tags
      end

      private def parse_kind_description(line : String) : KindDescription?
        parts = line.split("\t")
        return nil if parts.size < 3

        language_part = parts[0]
        language = language_part.split("!").last
        return nil unless language

        kind_part = parts[1]
        letter, name = kind_part.split(",", 2)
        return nil unless letter && name

        desc_part = parts[2]
        description = desc_part.gsub(/^\/|\/\s*$/, "")

        KindDescription.new(language, letter, name, description)
      end

      private def parse_line(line : String) : Tag?
        parts = line.split("\t")
        return nil if parts.size < 3

        name = parts[0]
        file = parts[1]
        pattern = parts[2]

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
            scope = ext[7..]
          when .starts_with?("class:")
            scope = ext[6..]
          when /^[a-z]$/
            kind = ext if kind.nil?
          when /^[a-z]+$/
            kind = ext if kind.nil?
          end
        end

        Tag.new(name, file, pattern, kind, scope, signature, line_num)
      end
    end
  end
end
