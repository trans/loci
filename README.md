# Loci

Unified code intelligence interface. Queries LSP servers with automatic ctags fallback. Works with any language.

## Features

- LSP-first symbol lookup with ctags fallback
- Auto-generates and refreshes ctags when source files change
- Respects `.gitignore` for smart file exclusions
- Configurable via `.loci.yml`
- Works with any LSP server (rust-analyzer, solargraph, pyright, gopls, etc.)

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

### With an LSP server

```bash
loci --lsp "rust-analyzer" --name Greeter
loci --lsp "solargraph stdio" --search "authenticate"
```

LSP is tried first. If it returns no results or isn't available, ctags kicks in automatically.

### Options

```
--tags=FILE      Path to tags file (default: tags)
--lsp=COMMAND    LSP server command (e.g. "rust-analyzer")
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

lsp:
  command: "rust-analyzer"

entries:
  - bin/myapp.cr     # Entry points for --dead analysis (auto-detected if single bin/*.cr)
```

All fields are optional. Sensible defaults are applied:

- If `.gitignore` exists, its patterns are used for ctags exclusions
- If no `.gitignore`, common directories are excluded automatically (node_modules, vendor, target, _build, etc.)
- Auto-generation is enabled by default
- CLI flags override config values

## How It Works

Loci uses a provider chain with fallback for symbol lookup:

1. **Ctags provider** (default) — parses standard ctags files (Universal/Exuberant Ctags format)
2. **LSP provider** (opt-in via `--lsp`) — spawns an LSP server, communicates via JSON-RPC over stdio

If the first provider returns no results or fails, the next one is tried. The ctags provider auto-generates its tags file if missing, and regenerates when source files are newer than the tags file.

### Reference finding (`--refs`)

Resolves the target to definitions via ctags, then scans all project source files for word-boundary matches. Results are filtered (comments removed, definitions subtracted), classified (`def`/`call`/`ref`), and ranked by proximity to the definition site.

### Dead code detection (`--dead`)

For Crystal projects, shells out to `crystal tool unreachable` for compiler-backed dead code analysis. A built-in filter suppresses false positives from `JSON::Serializable` classes and enum JSON hooks. Requires `entries:` in config or a single `bin/*.cr` file for entry-point auto-detection.

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
