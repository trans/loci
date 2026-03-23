# query-ctags

A fast ctags query tool for navigating codebases. Parse and query ctags files to find symbol definitions, list functions, and understand code structure.

## Features

- 🔍 Find symbol definitions by name
- 🔎 Search symbols by pattern (regex)
- 📁 List all symbols in a file
- 🏷️ Filter symbols by kind (function, class, method, etc.)
- 📊 List all available kinds and files
- ⚡ Fast parsing and querying

## Installation

### Build from source

```bash
crystal build src/query-ctags.cr --release -o bin/query-ctags
```

### Run with Crystal

```bash
crystal run src/query-ctags.cr -- [options]
```

## Usage

### Basic commands

Find a symbol by exact name:
```bash
./bin/query-ctags --name authenticate_user
```

Search for symbols matching a pattern:
```bash
./bin/query-ctags --search "auth.*user"
```

List all symbols in a file:
```bash
./bin/query-ctags --file src/auth.cr
```

Filter by kind (f=function, c=class, m=method, etc.):
```bash
./bin/query-ctags --kind c
```

List all available kinds:
```bash
./bin/query-ctags --list-kinds
```

List all files with tags:
```bash
./bin/query-ctags --list-files
```

### Options

- `--tags=FILE` - Path to tags file (default: `tags`)
- `--name=NAME` - Find exact tag by name
- `--search=PATTERN` - Search tags by regex pattern (case-insensitive)
- `--file=FILE` - List all tags in file
- `--kind=KIND` - Filter by kind (f, c, m, etc.)
- `--list-kinds` - List all tag kinds in the tags file
- `--list-files` - List all files with tags
- `-h, --help` - Show help
- `-v, --version` - Show version

## Development

### Running tests

```bash
crystal spec
```

### Building

```bash
shards build
```

## Tag File Format

This tool works with standard ctags format (Exuberant/Universal Ctags). Example tag line:

```
authenticate_user	lib/auth.ex	/^  def authenticate_user(conn, credentials) do$/;"	f	line:42
```

Format: `NAME<Tab>FILE<Tab>PATTERN;"<Tab>EXTENSIONS`

Common kind codes:
- `f` - function
- `c` - class
- `m` - method
- `v` - variable
- `t` - type/typedef
- `s` - struct

## Contributing

1. Fork it (<https://github.com/your-github-user/query-ctags/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Thomas Sawyer](https://github.com/your-github-user) - creator and maintainer

## License

MIT
