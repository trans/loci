# Loci — unified code intelligence interface

# Build the binary (3 min timeout — LLVM can run away)
build:
    timeout 180 shards build

# Build optimized release binary
release:
    timeout 180 crystal build src/loci.cr --release -o bin/loci

# Run specs
spec:
    crystal spec

# Run specs with verbose output
spec-verbose:
    crystal spec --verbose

# Clean build artifacts
clean:
    rm -f bin/loci bin/loci.dwarf

# Generate ctags for this project
tags:
    ctags -R --languages=Crystal src/
