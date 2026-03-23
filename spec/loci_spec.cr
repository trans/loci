require "./spec_helper"

describe Loci do
  it "has a version number" do
    Loci::VERSION.should_not be_nil
  end

  describe Loci::Tag do
    it "creates a tag with required fields" do
      tag = Loci::Tag.new("my_function", "src/file.cr", "/^def my_function$/")
      tag.name.should eq "my_function"
      tag.file.should eq "src/file.cr"
      tag.pattern.should eq "/^def my_function$/"
    end

    it "creates a tag with optional fields" do
      tag = Loci::Tag.new(
        "my_function",
        "src/file.cr",
        "/^def my_function$/",
        kind: "f",
        scope: "MyClass",
        line: 42
      )
      tag.kind.should eq "f"
      tag.scope.should eq "MyClass"
      tag.line.should eq 42
    end

    it "formats tag to string" do
      tag = Loci::Tag.new(
        "my_function",
        "src/file.cr",
        "/^def my_function$/",
        kind: "f",
        line: 42
      )
      tag.to_s.should contain "my_function"
      tag.to_s.should contain "src/file.cr"
      tag.to_s.should contain "kind:f"
      tag.to_s.should contain "line:42"
    end
  end

  describe Loci::Parser do
    it "parses a simple tag line" do
      # Create a temporary tags file
      File.write("spec/test_tags", "my_function\tsrc/file.cr\t/^def my_function$/;\tf\n")

      parser = Loci::Parser.new("spec/test_tags")
      tags = parser.parse

      tags.size.should eq 1
      tags[0].name.should eq "my_function"
      tags[0].file.should eq "src/file.cr"
      tags[0].kind.should eq "f"

      File.delete("spec/test_tags")
    end

    it "skips comment lines" do
      content = <<-TAGS
      !_TAG_FILE_FORMAT	2	/extended format/
      !_TAG_FILE_SORTED	1	/0=unsorted, 1=sorted, 2=foldcase/
      my_function\tsrc/file.cr\t/^def my_function$/;\tf
      TAGS

      File.write("spec/test_tags", content)

      parser = Loci::Parser.new("spec/test_tags")
      tags = parser.parse

      tags.size.should eq 1
      tags[0].name.should eq "my_function"

      File.delete("spec/test_tags")
    end
  end

  describe Loci::Querier do
    it "finds tags by exact name" do
      tags = [
        Loci::Tag.new("foo", "src/a.cr", "/^def foo$/", kind: "f"),
        Loci::Tag.new("bar", "src/b.cr", "/^def bar$/", kind: "f"),
        Loci::Tag.new("foo", "src/c.cr", "/^class Foo$/", kind: "c"),
      ]

      querier = Loci::Querier.new(tags)
      results = querier.find_by_name("foo")

      results.size.should eq 2
      results.all? { |t| t.name == "foo" }.should be_true
    end

    it "searches tags by pattern" do
      tags = [
        Loci::Tag.new("authenticate_user", "src/auth.cr", "/^def authenticate_user$/"),
        Loci::Tag.new("authorize_user", "src/auth.cr", "/^def authorize_user$/"),
        Loci::Tag.new("process_data", "src/data.cr", "/^def process_data$/"),
      ]

      querier = Loci::Querier.new(tags)
      results = querier.search_by_name("auth")

      results.size.should eq 2
      results.map(&.name).should contain "authenticate_user"
      results.map(&.name).should contain "authorize_user"
    end

    it "finds tags by file" do
      tags = [
        Loci::Tag.new("foo", "src/a.cr", "/^def foo$/"),
        Loci::Tag.new("bar", "src/a.cr", "/^def bar$/"),
        Loci::Tag.new("baz", "src/b.cr", "/^def baz$/"),
      ]

      querier = Loci::Querier.new(tags)
      results = querier.find_by_file("src/a.cr")

      results.size.should eq 2
      results.all? { |t| t.file == "src/a.cr" }.should be_true
    end

    it "filters tags by kind" do
      tags = [
        Loci::Tag.new("MyClass", "src/a.cr", "/^class MyClass$/", kind: "c"),
        Loci::Tag.new("my_method", "src/a.cr", "/^def my_method$/", kind: "f"),
        Loci::Tag.new("OtherClass", "src/b.cr", "/^class OtherClass$/", kind: "c"),
      ]

      querier = Loci::Querier.new(tags)
      results = querier.find_by_kind("c")

      results.size.should eq 2
      results.all? { |t| t.kind == "c" }.should be_true
    end

    it "lists unique kinds" do
      tags = [
        Loci::Tag.new("MyClass", "src/a.cr", "/^class MyClass$/", kind: "c"),
        Loci::Tag.new("my_method", "src/a.cr", "/^def my_method$/", kind: "f"),
        Loci::Tag.new("my_var", "src/a.cr", "/^my_var = 1$/", kind: "v"),
        Loci::Tag.new("OtherClass", "src/b.cr", "/^class OtherClass$/", kind: "c"),
      ]

      querier = Loci::Querier.new(tags)
      kinds = querier.list_kinds

      kinds.should eq ["c", "f", "v"]
    end

    it "lists unique files" do
      tags = [
        Loci::Tag.new("foo", "src/a.cr", "/^def foo$/"),
        Loci::Tag.new("bar", "src/a.cr", "/^def bar$/"),
        Loci::Tag.new("baz", "src/b.cr", "/^def baz$/"),
        Loci::Tag.new("qux", "src/c.cr", "/^def qux$/"),
      ]

      querier = Loci::Querier.new(tags)
      files = querier.list_files

      files.should eq ["src/a.cr", "src/b.cr", "src/c.cr"]
    end
  end
end
