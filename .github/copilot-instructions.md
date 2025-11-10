# Icarus Mod Tools - AI Coding Instructions

## Project Overview

This is a Ruby CLI gem for managing an Icarus game mods database with bidirectional sync between GitHub repositories and Google Firestore. The tool (`imt`) discovers mod/tool metadata files across repositories and maintains a centralized database.

## Architecture Components

### Data Flow
1. **GitHub → Firestore**: Scan repositories for `modinfo.json`/`toolinfo.json`, sync to meta collections
2. **Meta → Database**: Process meta lists to create/update individual mod/tool documents
3. **Validation**: All data is validated before database operations

### Core Classes
- `Icarus::Mod::Config`: JSON config reader (`.imtconfig.json` in user home)
- `Icarus::Mod::Firestore`: Google Cloud Firestore client with collection management
- `Icarus::Mod::Github`: Octokit wrapper with recursive file discovery
- `Icarus::Mod::Tools::Baseinfo`: Shared validation/transformation for mod/tool data
- `Icarus::Mod::CLI::*`: Thor-based command structure with subcommands

## Development Patterns

### CLI Structure
- Inherit from `CLI::Base` (provides common options like `--config`, `--version`)
- Subcommands inherit from `CLI::SubcommandBase`
- Use Thor's `desc` and `method_option` for command documentation
- Global `$firestore` variable for shared Firestore instance in sync commands

### Configuration Management
```ruby
# Always validate config exists in CLI commands
unless File.exist?(options[:config])
  warn "Could not find config..."
  exit 1
end

Icarus::Mod::Config.read(options[:config])
```

### Error Handling
- Use `Icarus::Mod::Tools::Error` for domain-specific errors
- Commands should `rescue` and `warn` user-friendly messages
- Validation errors stored in `@errors` array, warnings in `@warnings`

### Data Validation
- All mod/tool data inherits validation from `Baseinfo`
- Required fields: `name`, `author`, `description`
- URL validation for `imageURL`, `readmeURL`, file URLs
- File types must match `/\.(zip|pak|exmodz?)/i` pattern
- Version strings should match `/^\d+[.\d+]*/`

### Testing
- RSpec with fixtures in `spec/fixtures/`
- Use `--format Fuubar` for progress display
- Run tests with `bundle exec rake` (includes StandardRB linting)
- Random test order with `config.order = :random`

## Key Workflows

### Development Setup
```bash
bin/setup          # Install dependencies
bundle exec rake   # Run tests + linting
bin/console        # Interactive console
```

### Database Operations
- Collections: `meta/modinfo`, `meta/toolinfo`, `meta/repos`, `mods`, `tools`
- Sync operations support `--dry-run` for safe testing
- Updates use merge semantics to preserve existing data
- Automatic cleanup removes orphaned documents

### File Discovery
- GitHub API recursively scans repositories for `.json` files
- Caches results per repository instance for performance
- Pattern matching: `/modinfo|toolinfo/i` for relevant files

## Integration Points

### External APIs
- **Google Firestore**: Document database with nested collections
- **GitHub API**: Repository scanning with OAuth token authentication
- **Thor**: CLI framework for command structure and option parsing

### Configuration Dependencies
- `.imtconfig.json` in user home directory with Firebase credentials and GitHub token
- Collection paths configurable via `firebase.collections` config section
- See `imtconfig.sample.json` for required structure

## Common Gotchas

- Firestore credentials must be full JSON object, not file path
- GitHub repo format: `owner/repo` (strips URL prefixes automatically)
- Ruby 3.1+ required for pattern matching and other modern features
- WSL2/Linux recommended over Windows for reliability
- Verbose flags (`-v`, `-vv`) control output detail levels
- **SSL Certificate Issues**: Ruby 3.4+ with newer OpenSSL may fail certificate verification for CRL checking. Configure custom SSL verification in HTTP helpers to handle certificate validation errors
