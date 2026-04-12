# Loci

Unified code intelligence interface. Fast, stateless symbol lookup with compiler-backed dead code detection and heuristic reference finding. Designed for AI coding agents and CLI workflows.

## Features

- Fast symbol lookup via ctags (auto-generated, auto-refreshed)
- Reference finding with heuristic classification (`--refs`)
- Compiler-backed dead code detection (`--dead`)
- Respects `.gitignore` for smart file exclusions
- Configurable via `.loci.yml`

## Installation

```bash
shards build
```

Or build a release binary:

```bash
crystal build bin/loci.cr --release -o bin/loci
```

Requires [Universal Ctags](https://ctags.io/) for the ctags provider.

## Usage

Loci auto-generates ctags on first run. Just query:

```bash
loci --name authenticate_user
loci --search "auth.*user"
loci --file src/auth.cr
loci --kind f
loci --list-kinds
loci --list-files
loci --force --search "Builder|Server"
loci --refs authenticate_user
loci --refs "UserController#create"
loci --refs src/auth.cr:42
loci --refs authenticate_user --no-defs --limit=50
loci --dead
```

### Options

```
--tags=FILE      Path to tags file (default: tags)
--root=DIR       Project root directory (default: current)
--no-auto        Disable auto-generation of tags
--force          Regenerate tags before querying
--name=NAME      Find exact symbol by name
--search=PATTERN Search symbols by regex pattern
--file=FILE      List all symbols in file
--kind=KIND      Filter by kind (f, c, m, etc.)
--list-kinds     List all symbol kinds
--list-files     List all files with symbols
--refs=TARGET    Find references to a symbol (name, Scope#name, file:line)
--no-defs        Exclude definitions from --refs output
--limit=N        Max results for --refs (default: 200)
--dead           Report unreachable/dead code
-h, --help       Show help
-v, --version    Show version
```

## Configuration

Create a `.loci.yml` in your project root:

```yaml
ctags:
  exclude:
    - node_modules
    - vendor
  flags:
    - "--languages=Crystal,Ruby"
  file: tags
  auto: true

entries:
  - bin/myapp.cr     # Entry points for --dead analysis (auto-detected if single bin/*.cr)
```

All fields are optional. Sensible defaults are applied:

- If `.gitignore` exists, its patterns are used for ctags exclusions
- If no `.gitignore`, common directories are excluded automatically (node_modules, vendor, target, _build, etc.)
- Auto-generation is enabled by default
- CLI flags override config values

## How It Works

**Symbol lookup** uses ctags (Universal/Exuberant Ctags format). The tags file is auto-generated on first run and regenerated when source files are newer than the tags file.

### Reference finding (`--refs`)

Resolves the target to definitions via ctags, then scans all project source files for word-boundary matches. Results are filtered (comments removed, definitions subtracted), classified (`def`/`call`/`ref`), and ranked by proximity to the definition site.

### Dead code detection (`--dead`)

For Crystal projects, shells out to `crystal tool unreachable` for compiler-backed dead code analysis. A built-in filter suppresses false positives from `JSON::Serializable` classes and enum JSON hooks. Requires `entries:` in config or a single `bin/*.cr` file for entry-point auto-detection.

## Why not LSP?

Loci intentionally does not use LSP. We tried it and removed it. Here's why:

**LSP is designed for IDEs, not CLI tools.** LSP servers are long-running, stateful processes with significant startup cost (rust-analyzer can take 30+ seconds to index). Loci is a one-shot query tool — spawning, initializing, querying, and tearing down an LSP server for a single symbol lookup is the wrong cost model.

**The unique value is narrow.** LSP offers definitions, references, hover, rename, diagnostics, and code actions. But ctags handles definitions faster. Heuristic grep handles references well enough for code navigation. And compiler-native tools (like `crystal tool unreachable`) handle dead code detection better than LSP can.

**Each language's own toolchain is better.** Rather than a generic LSP client that handles every server's quirks, loci uses language-specific compiler tools directly. Crystal's `crystal tool` suite provides authoritative dead code analysis in under a second, with zero configuration. The same pattern extends to other languages — `go vet`, `cargo`, `pyright --outputjson` — each invoked statelessly.

**Friction kills adoption.** When an AI coding agent tried loci with LSP, the server wasn't installed. The agent fell back to ctags, found it insufficient for references, and bailed to grep. The lesson: zero-setup tools get used, tools that require per-language server installation don't.

LSP support existed in earlier versions of loci. If a future use case genuinely requires it, the implementation is preserved in git history (commit `1d12c02`).

## Development

```bash
just spec          # Run tests
just build         # Build binary
just release       # Build optimized binary
just clean         # Remove build artifacts
just tags          # Generate ctags for this project
```

## Contributing

1. Fork it (<https://github.com/trans/loci/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT
