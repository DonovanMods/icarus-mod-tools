# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Icarus Mod Tools (`imt`) is a Ruby CLI gem that manages a bidirectional sync between GitHub repositories and Google Firestore for the Icarus game mods database. The tool discovers `modinfo.json` and `toolinfo.json` files across repositories and maintains a centralized Firestore database.

## Development Commands

### Setup & Installation

```bash
bin/setup                    # Install dependencies
bundle install               # Install gems
bundle exec rake install     # Install gem locally
```

### Testing

```bash
bundle exec rake             # Run tests (default task)
bundle exec rspec            # Run tests only (with Fuubar formatter)
bundle exec rspec spec/path/to/file_spec.rb  # Run single test file
bundle exec rspec spec/path/to/file_spec.rb:42  # Run single test at line 42
guard                        # Auto-run tests on file changes
```

### Console & Debugging

```bash
bin/console                  # Interactive IRB console with project loaded
```

### Running the CLI

```bash
bundle exec exe/imt [command]  # Run CLI during development
imt [command]                  # Run installed gem
```

## Architecture

### Data Flow Pipeline

The tool implements a two-stage sync pipeline:

1. **GitHub → Meta Collections**: Scan repositories for metadata files and sync to `meta/modinfo`, `meta/toolinfo`, `meta/repos`
2. **Meta → Entity Collections**: Process meta lists to populate/update `mods` and `tools` collections

All operations support `--dry-run` for safe testing.

### Core Components

**CLI Layer** (`lib/icarus/mod/cli/`)

- `Command`: Main entry point, defines subcommands (sync, list, add, remove, validate)
- `Base`: Inherited by all commands, provides `--config` and `--version` options
- `SubcommandBase`: Base for subcommands, adds `--verbose` option
- Subcommands: `Sync`, `List`, `Add`, `Remove`, `Validate` (all Thor-based)

**Data Models** (`lib/icarus/mod/tools/`)

- `Baseinfo`: Shared validation/transformation logic for mod and tool data
- `Modinfo`: Validates and processes mod metadata
- `Toolinfo`: Validates and processes tool metadata
- `Validator`: Standalone validation utilities

**Sync Operations** (`lib/icarus/mod/tools/sync/`)

- `ModinfoList`: GitHub → meta/modinfo sync
- `ToolinfoList`: GitHub → meta/toolinfo sync
- `Mods`: meta/modinfo → mods sync
- `Tools`: meta/toolinfo → tools sync
- `Helpers`: HTTP utilities with custom SSL verification for Ruby 3.4+ CRL issues

**External Services** (`lib/icarus/mod/`)

- `Firestore`: Google Cloud Firestore client with collection management
- `Github`: Octokit wrapper with recursive file discovery
- `Config`: JSON config reader for `.imtconfig.json`

### Global State

The CLI uses a global `$firestore` variable in sync commands to share the Firestore instance across operations. This is set in `CLI::Sync` and used by sync modules.

### Configuration

The tool reads from `~/.imtconfig.json` (configurable via `--config`):

- Firebase credentials (full JSON object, not path)
- GitHub OAuth token
- Collection paths (configurable)

See README.md for configuration structure.

## Development Patterns

### CLI Command Structure

All commands inherit from `CLI::Base` or `CLI::SubcommandBase`:

```ruby
class MyCommand < CLI::SubcommandBase
  desc "mycommand ARGS", "Description"
  method_option :my_option, aliases: "-m", type: :string, desc: "Option description"
  def mycommand(args)
    # Config is already loaded by CLI::Command#initialize
    # Access via Icarus::Mod::Config.config
  end
end
```

### Error Handling

Domain errors use `Icarus::Mod::Tools::Error`. Validation errors/warnings are stored in `@errors` and `@warnings` arrays on data model instances.

```ruby
rescue Icarus::Mod::Tools::Error => e
  warn "Error: #{e.message}"
  exit 1
end
```

### Validation Rules

All mod/tool data inherits from `Baseinfo`:

- Required fields: `name`, `author`, `description`
- URL validation for `imageURL`, `readmeURL`, file URLs
- File types must match `/\.(zip|pak|exmodz?)/i`
- Version strings should match `/^\d+[.\d+]*/`

### SSL Certificate Handling

Ruby 3.4+ with newer OpenSSL may fail CRL checking. The codebase handles this in `Sync::Helpers#retrieve_from_url` with a custom `verify_callback` that allows `V_ERR_UNABLE_TO_GET_CRL` errors.

### Testing Patterns

- Fixtures in `spec/fixtures/`
- Tests run in random order (`config.order = :random`)
- Use `:focus` metadata to run specific tests
- Fuubar formatter provides progress bar display

## Key Gotchas

- **Firestore credentials**: Must be the full JSON object in config, not a file path
- **GitHub repo format**: `owner/repo` format (URL prefixes are stripped automatically)
- **Ruby version**: 3.1+ required for pattern matching and modern features
- **Platform**: WSL2/Linux recommended; not tested on Windows
- **Require paths**: The gemspec sets `require_paths` to both `lib` and `lib/icarus/mod`, so files use relative requires like `require "cli/base"` instead of `require_relative`
- **Verbosity**: `-v` and `-vv` flags control output detail in subcommands
