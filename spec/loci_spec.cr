require "./spec_helper"

describe Loci do
  it "has a version number" do
    Loci::VERSION.should_not be_nil
  end

  describe Loci::Symbol do
    it "creates a symbol with required fields" do
      sym = Loci::Symbol.new("my_function", "src/file.cr")
      sym.name.should eq "my_function"
      sym.file.should eq "src/file.cr"
    end

    it "creates a symbol with all fields" do
      sym = Loci::Symbol.new(
        "my_function",
        "src/file.cr",
        line: 42,
        kind: "function",
        scope: "MyClass",
        signature: "(x : Int32)",
        pattern: "/^def my_function$/"
      )
      sym.line.should eq 42
      sym.kind.should eq "function"
      sym.scope.should eq "MyClass"
      sym.signature.should eq "(x : Int32)"
      sym.pattern.should eq "/^def my_function$/"
    end

    it "formats symbol to string" do
      sym = Loci::Symbol.new(
        "my_function",
        "src/file.cr",
        line: 42,
        kind: "function"
      )
      sym.to_s.should contain "my_function"
      sym.to_s.should contain "src/file.cr"
      sym.to_s.should contain "kind:function"
      sym.to_s.should contain "line:42"
    end
  end

  describe Loci::Config do
    it "returns defaults when no config file exists" do
      config = Loci::Config.load("/nonexistent/path")
      config.ctags.file.should eq "tags"
      config.ctags.auto.should be_true
      config.ctags.exclude.should be_empty
      config.ctags.flags.should be_empty
      config.entries.should be_empty
    end

    it "loads from a YAML file" do
      yaml = <<-YAML
      ctags:
        exclude:
          - node_modules
          - vendor
        flags:
          - "--languages=Crystal"
        file: custom_tags
        auto: false
      entries:
        - bin/myapp.cr
      YAML

      Dir.mkdir_p("spec/test_config")
      File.write("spec/test_config/.loci.yml", yaml)

      config = Loci::Config.load("spec/test_config")
      config.ctags.file.should eq "custom_tags"
      config.ctags.auto.should be_false
      config.ctags.exclude.should eq ["node_modules", "vendor"]
      config.ctags.flags.should eq ["--languages=Crystal"]
      config.entries.should eq ["bin/myapp.cr"]

      File.delete("spec/test_config/.loci.yml")
      Dir.delete("spec/test_config")
    end

    it "handles partial config" do
      yaml = <<-YAML
      ctags:
        file: my_tags
      YAML

      Dir.mkdir_p("spec/test_config")
      File.write("spec/test_config/.loci.yml", yaml)

      config = Loci::Config.load("spec/test_config")
      config.ctags.file.should eq "my_tags"
      config.ctags.auto.should be_true
      config.ctags.exclude.should be_empty
      config.entries.should be_empty

      File.delete("spec/test_config/.loci.yml")
      Dir.delete("spec/test_config")
    end
  end

  describe Loci::Ctags::Tag do
    it "creates a tag with required fields" do
      tag = Loci::Ctags::Tag.new("my_function", "src/file.cr", "/^def my_function$/")
      tag.name.should eq "my_function"
      tag.file.should eq "src/file.cr"
      tag.pattern.should eq "/^def my_function$/"
    end

    it "creates a tag with optional fields" do
      tag = Loci::Ctags::Tag.new(
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

    it "converts to symbol" do
      tag = Loci::Ctags::Tag.new(
        "my_function",
        "src/file.cr",
        "/^def my_function$/",
        kind: "f",
        scope: "MyClass",
        line: 42
      )
      sym = tag.to_symbol
      sym.name.should eq "my_function"
      sym.file.should eq "src/file.cr"
      sym.kind.should eq "f"
      sym.scope.should eq "MyClass"
      sym.line.should eq 42
      sym.pattern.should eq "/^def my_function$/"
    end
  end

  describe Loci::Ctags::Parser do
    it "parses a simple tag line" do
      File.write("spec/test_tags", "my_function\tsrc/file.cr\t/^def my_function$/;\"\tf\n")

      parser = Loci::Ctags::Parser.new("spec/test_tags")
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
      my_function\tsrc/file.cr\t/^def my_function$/;\"\tf
      TAGS

      File.write("spec/test_tags", content)

      parser = Loci::Ctags::Parser.new("spec/test_tags")
      tags = parser.parse

      tags.size.should eq 1
      tags[0].name.should eq "my_function"

      File.delete("spec/test_tags")
    end
  end

  describe Loci::Ctags::Querier do
    it "finds tags by exact name" do
      tags = [
        Loci::Ctags::Tag.new("foo", "src/a.cr", "/^def foo$/", kind: "f"),
        Loci::Ctags::Tag.new("bar", "src/b.cr", "/^def bar$/", kind: "f"),
        Loci::Ctags::Tag.new("foo", "src/c.cr", "/^class Foo$/", kind: "c"),
      ]

      querier = Loci::Ctags::Querier.new(tags)
      results = querier.find_by_name("foo")

      results.size.should eq 2
      results.all? { |t| t.name == "foo" }.should be_true
    end

    it "searches tags by pattern" do
      tags = [
        Loci::Ctags::Tag.new("authenticate_user", "src/auth.cr", "/^def authenticate_user$/"),
        Loci::Ctags::Tag.new("authorize_user", "src/auth.cr", "/^def authorize_user$/"),
        Loci::Ctags::Tag.new("process_data", "src/data.cr", "/^def process_data$/"),
      ]

      querier = Loci::Ctags::Querier.new(tags)
      results = querier.search_by_name("auth")

      results.size.should eq 2
      results.map(&.name).should contain "authenticate_user"
      results.map(&.name).should contain "authorize_user"
    end

    it "finds tags by file" do
      tags = [
        Loci::Ctags::Tag.new("foo", "src/a.cr", "/^def foo$/"),
        Loci::Ctags::Tag.new("bar", "src/a.cr", "/^def bar$/"),
        Loci::Ctags::Tag.new("baz", "src/b.cr", "/^def baz$/"),
      ]

      querier = Loci::Ctags::Querier.new(tags)
      results = querier.find_by_file("src/a.cr")

      results.size.should eq 2
      results.all? { |t| t.file == "src/a.cr" }.should be_true
    end

    it "filters tags by kind" do
      tags = [
        Loci::Ctags::Tag.new("MyClass", "src/a.cr", "/^class MyClass$/", kind: "c"),
        Loci::Ctags::Tag.new("my_method", "src/a.cr", "/^def my_method$/", kind: "f"),
        Loci::Ctags::Tag.new("OtherClass", "src/b.cr", "/^class OtherClass$/", kind: "c"),
      ]

      querier = Loci::Ctags::Querier.new(tags)
      results = querier.find_by_kind("c")

      results.size.should eq 2
      results.all? { |t| t.kind == "c" }.should be_true
    end

    it "lists unique kinds" do
      tags = [
        Loci::Ctags::Tag.new("MyClass", "src/a.cr", "/^class MyClass$/", kind: "c"),
        Loci::Ctags::Tag.new("my_method", "src/a.cr", "/^def my_method$/", kind: "f"),
        Loci::Ctags::Tag.new("my_var", "src/a.cr", "/^my_var = 1$/", kind: "v"),
        Loci::Ctags::Tag.new("OtherClass", "src/b.cr", "/^class OtherClass$/", kind: "c"),
      ]

      querier = Loci::Ctags::Querier.new(tags)
      kinds = querier.list_kinds

      kinds.should eq ["c", "f", "v"]
    end

    it "lists unique files" do
      tags = [
        Loci::Ctags::Tag.new("foo", "src/a.cr", "/^def foo$/"),
        Loci::Ctags::Tag.new("bar", "src/a.cr", "/^def bar$/"),
        Loci::Ctags::Tag.new("baz", "src/b.cr", "/^def baz$/"),
        Loci::Ctags::Tag.new("qux", "src/c.cr", "/^def qux$/"),
      ]

      querier = Loci::Ctags::Querier.new(tags)
      files = querier.list_files

      files.should eq ["src/a.cr", "src/b.cr", "src/c.cr"]
    end
  end

  describe Loci::Ctags::Provider do
    it "returns symbols from a tags file" do
      File.write("spec/test_tags", "my_function\tsrc/file.cr\t/^def my_function$/;\"\tf\tline:10\n")

      provider = Loci::Ctags::Provider.new("spec/test_tags")
      results = provider.find_by_name("my_function")

      results.size.should eq 1
      results[0].should be_a Loci::Symbol
      results[0].name.should eq "my_function"
      results[0].file.should eq "src/file.cr"
      results[0].line.should eq 10

      File.delete("spec/test_tags")
    end
  end

  describe Loci::Ctags::Generator do
    it "checks if ctags is available" do
      Loci::Ctags::Generator.ctags_available?.should be_true
    end

    it "generates a tags file" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/example.cr"), "def hello\n  puts \"hello\"\nend\n")

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        tags_path = generator.generate

        File.exists?(tags_path).should be_true
        File.read(tags_path).should contain "hello"
      end
    end

    it "detects stale tags file" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/example.cr"), "def hello\nend\n")

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        tags_path = generator.generate

        generator.stale?(tags_path).should be_false

        sleep 0.1.seconds
        File.write(File.join(dir, "src/example.cr"), "def hello\nend\ndef world\nend\n")

        generator.stale?(tags_path).should be_true
      end
    end

    it "ensure_fresh generates when missing" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/example.cr"), "def hello\nend\n")

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        tags_path = generator.ensure_fresh

        File.exists?(tags_path).should be_true
      end
    end

    it "ensure_fresh regenerates when stale" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/example.cr"), "def hello\nend\n")

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        tags_path = generator.generate
        old_mtime = File.info(tags_path).modification_time

        sleep 0.1.seconds
        File.write(File.join(dir, "src/example.cr"), "def hello\nend\ndef world\nend\n")

        generator.ensure_fresh
        new_mtime = File.info(tags_path).modification_time

        (new_mtime > old_mtime).should be_true
      end
    end

    it "respects .gitignore exclusions in staleness check" do
      with_test_project do |dir|
        Dir.mkdir_p(File.join(dir, "vendor"))
        File.write(File.join(dir, ".gitignore"), "vendor/\n")
        File.write(File.join(dir, "src/example.cr"), "def hello\nend\n")

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        tags_path = generator.generate

        generator.stale?(tags_path).should be_false

        # Touching a file in vendor/ should NOT trigger staleness
        sleep 0.1.seconds
        File.write(File.join(dir, "vendor/dep.cr"), "# dependency")

        generator.stale?(tags_path).should be_false

        # Touching a file in src/ SHOULD trigger staleness
        sleep 0.1.seconds
        File.write(File.join(dir, "src/example.cr"), "def changed\nend\n")

        generator.stale?(tags_path).should be_true
      end
    end

    it "respects nested .gitignore exclusions during generation" do
      with_test_project do |dir|
        Dir.mkdir_p(File.join(dir, "frontend/node_modules/pkg"))
        Dir.mkdir_p(File.join(dir, "frontend/src"))
        File.write(File.join(dir, "frontend/.gitignore"), "node_modules\n")
        File.write(File.join(dir, "frontend/src/app.js"), "function keepMe() {}\n")
        File.write(File.join(dir, "frontend/node_modules/pkg/ignored.js"), "function skipMe() {}\n")

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        tags_path = generator.generate
        tags = File.read(tags_path)

        tags.should contain "keepMe"
        tags.should_not contain "skipMe"
      end
    end
  end

  describe Loci::Analysis::Dead do
    it "parses crystal tool unreachable output" do
      output = <<-OUT
      src/foo.cr:10:5\tMyApp::Foo#bar\t3 lines
      src/baz.cr:42:7\tMyApp::Baz#qux\t10 lines
      OUT

      results = Loci::Analysis::Dead.parse_crystal_output(output)
      results.size.should eq 2

      results[0].file.should eq "src/foo.cr"
      results[0].line.should eq 10
      results[0].col.should eq 5
      results[0].scope.should eq "MyApp::Foo"
      results[0].name.should eq "bar"
      results[0].kind.should eq "method"
      results[0].size.should eq 3

      results[1].file.should eq "src/baz.cr"
      results[1].line.should eq 42
      results[1].name.should eq "qux"
      results[1].size.should eq 10
    end

    it "handles class methods in qualified names" do
      scope, name, kind = Loci::Analysis::Dead.parse_qualified("MyApp::Foo.create")
      scope.should eq "MyApp::Foo"
      name.should eq "create"
      kind.should eq "class_method"
    end

    it "handles top-level defs" do
      scope, name, kind = Loci::Analysis::Dead.parse_qualified("main")
      scope.should be_nil
      name.should eq "main"
      kind.should eq "def"
    end

    it "skips malformed lines" do
      output = <<-OUT
      not a valid line
      also\tinvalid
      src/ok.cr:1:1\tFoo#bar\t2 lines
      OUT

      results = Loci::Analysis::Dead.parse_crystal_output(output)
      results.size.should eq 1
      results[0].name.should eq "bar"
    end
  end

  describe Loci::Analysis::JsonSerializableFilter do
    it "filters initialize in JSON::Serializable classes" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/example.cr"), <<-CR
        class Foo
          include JSON::Serializable
          property name : String

          def initialize(@name : String)
          end
        end
        CR
        )

        results = [
          Loci::Analysis::Dead::Result.new(
            file: "src/example.cr", line: 5, col: 5,
            scope: "Foo", name: "initialize", kind: "method", size: 2
          ),
        ]

        filter = Loci::Analysis::JsonSerializableFilter.new(dir)
        filtered = filter.filter(results)
        filtered.should be_empty
      end
    end

    it "keeps initialize in non-serializable classes" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/example.cr"), <<-CR
        class Foo
          property name : String

          def initialize(@name : String)
          end
        end
        CR
        )

        results = [
          Loci::Analysis::Dead::Result.new(
            file: "src/example.cr", line: 4, col: 5,
            scope: "Foo", name: "initialize", kind: "method", size: 2
          ),
        ]

        filter = Loci::Analysis::JsonSerializableFilter.new(dir)
        filtered = filter.filter(results)
        filtered.size.should eq 1
      end
    end

    it "filters enum JSON methods" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/example.cr"), <<-CR
        enum Color
          Red
          Blue

          def to_json(json : JSON::Builder) : Nil
            json.number(value)
          end
        end
        CR
        )

        results = [
          Loci::Analysis::Dead::Result.new(
            file: "src/example.cr", line: 5, col: 5,
            scope: "Color", name: "to_json", kind: "method", size: 3
          ),
        ]

        filter = Loci::Analysis::JsonSerializableFilter.new(dir)
        filtered = filter.filter(results)
        filtered.should be_empty
      end
    end

    it "keeps non-reflection methods even in serializable classes" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/example.cr"), <<-CR
        class Foo
          include JSON::Serializable
          property name : String

          def unused_helper
          end
        end
        CR
        )

        results = [
          Loci::Analysis::Dead::Result.new(
            file: "src/example.cr", line: 5, col: 5,
            scope: "Foo", name: "unused_helper", kind: "method", size: 2
          ),
        ]

        filter = Loci::Analysis::JsonSerializableFilter.new(dir)
        filtered = filter.filter(results)
        filtered.size.should eq 1
      end
    end
  end

  describe Loci::Analysis::Refs do
    it "finds references to a symbol across files" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/foo.cr"), <<-CR
        def greet(name)
          puts "hello"
        end
        CR
        )
        File.write(File.join(dir, "src/bar.cr"), <<-CR
        def main
          greet("world")
          # greet is great
        end
        CR
        )

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        generator.generate

        tags_path = File.join(dir, config.ctags.file)
        providers = [Loci::Ctags::Provider.new(tags_path)] of Loci::Provider
        client = Loci::Client.new(providers)

        finder = Loci::Analysis::Refs.new(dir, client)
        result = finder.find("greet")

        result.name.should eq "greet"
        result.definitions.size.should eq 1

        call_refs = result.references.select { |r| r.kind == "call" }
        call_refs.any? { |r| r.file == "src/bar.cr" && r.snippet.includes?("greet(\"world\")") }.should be_true
      end
    end

    it "filters comment lines" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/foo.cr"), <<-CR
        def greet
        end
        CR
        )
        File.write(File.join(dir, "src/bar.cr"), <<-CR
        # greet is mentioned in a comment
        greet
        CR
        )

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        generator.generate

        tags_path = File.join(dir, config.ctags.file)
        providers = [Loci::Ctags::Provider.new(tags_path)] of Loci::Provider
        client = Loci::Client.new(providers)

        finder = Loci::Analysis::Refs.new(dir, client)
        result = finder.find("greet", include_defs: false)

        result.references.none? { |r| r.snippet.starts_with?("#") }.should be_true
        result.references.size.should eq 1
      end
    end

    it "classifies call vs ref vs def" do
      with_test_project do |dir|
        File.write(File.join(dir, "src/foo.cr"), <<-CR
        class Greeter
          def greet
          end
        end
        CR
        )
        File.write(File.join(dir, "src/bar.cr"), <<-CR
        x = Greeter.new
        x.greet
        val : Greeter = x
        CR
        )

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        generator.generate

        tags_path = File.join(dir, config.ctags.file)
        providers = [Loci::Ctags::Provider.new(tags_path)] of Loci::Provider
        client = Loci::Client.new(providers)

        finder = Loci::Analysis::Refs.new(dir, client)
        result = finder.find("Greeter", include_defs: false)

        kinds = result.references.map(&.kind)
        kinds.should contain "ref"   # Greeter.new and : Greeter are both refs
        result.references.size.should eq 2
      end
    end

    it "respects --limit" do
      with_test_project do |dir|
        lines = (1..10).map { |i| "greet_#{i}" }.join("\n")
        File.write(File.join(dir, "src/foo.cr"), "def greet\nend\n")
        File.write(File.join(dir, "src/bar.cr"), (1..10).map { "greet" }.join("\n"))

        config = Loci::Config.new
        generator = Loci::Ctags::Generator.new(dir, config)
        generator.generate

        tags_path = File.join(dir, config.ctags.file)
        providers = [Loci::Ctags::Provider.new(tags_path)] of Loci::Provider
        client = Loci::Client.new(providers)

        finder = Loci::Analysis::Refs.new(dir, client)
        result = finder.find("greet", limit: 3, include_defs: false)

        result.references.size.should eq 3
        result.total_matches.should eq 10
      end
    end
  end

  describe Loci::Client do
    it "returns results from the first provider that has them" do
      File.write("spec/test_tags", "my_function\tsrc/file.cr\t/^def my_function$/;\"\tf\n")

      providers = [Loci::Ctags::Provider.new("spec/test_tags")] of Loci::Provider
      client = Loci::Client.new(providers)
      results = client.find_by_name("my_function")

      results.size.should eq 1
      results[0].name.should eq "my_function"

      File.delete("spec/test_tags")
    end

    it "returns empty array when no providers have results" do
      File.write("spec/test_tags", "my_function\tsrc/file.cr\t/^def my_function$/;\"\tf\n")

      providers = [Loci::Ctags::Provider.new("spec/test_tags")] of Loci::Provider
      client = Loci::Client.new(providers)
      results = client.find_by_name("nonexistent")

      results.should be_empty

      File.delete("spec/test_tags")
    end

    it "falls through to next provider on empty results" do
      File.write("spec/test_tags_empty", "")
      File.write("spec/test_tags_full", "my_function\tsrc/file.cr\t/^def my_function$/;\"\tf\n")

      providers = [
        Loci::Ctags::Provider.new("spec/test_tags_empty"),
        Loci::Ctags::Provider.new("spec/test_tags_full"),
      ] of Loci::Provider
      client = Loci::Client.new(providers)
      results = client.find_by_name("my_function")

      results.size.should eq 1
      results[0].name.should eq "my_function"

      File.delete("spec/test_tags_empty")
      File.delete("spec/test_tags_full")
    end

    it "falls through on all query types" do
      File.write("spec/test_tags", "foo\tsrc/a.cr\t/^def foo$/;\"\tf\tline:1\nbar\tsrc/b.cr\t/^def bar$/;\"\tf\tline:5\n")

      providers = [Loci::Ctags::Provider.new("spec/test_tags")] of Loci::Provider
      client = Loci::Client.new(providers)

      client.search_by_name("foo").size.should eq 1
      client.find_by_file("src/a.cr").size.should eq 1
      client.find_by_kind("f").size.should eq 2
      client.list_files.should eq ["src/a.cr", "src/b.cr"]

      File.delete("spec/test_tags")
    end
  end
end
