# Change Log

All notable changes to this project will be documented in this file.

## History (reverse chronological order)

### Unreleased

- Add `imt validate repo OWNER/REPO [--json]`, a read-only pre-check for a repo before it is added to `meta/repos` (repo state, info files, entry validation and link checks; exits 0/1/2)

### v3.1.0 - 2026-10-30

- `imt sync mods`/`tools --dry-run` now lists the entries a real run would delete, and warns when the mass-delete brake would refuse (a real run would exit 1 without `--force`)
- Document `imt add --dry-run` in the README
- Update `google-cloud-firestore` to 3.x and `octokit` to 10.x (no API changes affect `imt`)
- Update development tools (`pry` 0.16, `guard`, `rake`)

### v3.0.0 - 2026-10-30

**Breaking:** requires Ruby 4.0 or greater. Sync commands now exit 1 on failure, and `imt sync mods`/`tools` refuse a mass delete without `--force`.

- Require Ruby 4.0 or greater (was 3.1)
  - Fixes `imt sync` crashing during Firestore authentication with `wrong number of arguments (given 2, expected 1)` on Ruby 3.1 once `json` 3.x is installed; `multi_json` releases that support `json` 3.x (1.21.2+) need Ruby 3.2 or newer
- Update `multi_json` to 1.21.2
- Declare `ostruct` as a runtime dependency; it is no longer a default gem on Ruby 4.0, so a plain `gem install` could fail to load the config
- Update `faraday`, `jwt`, `addressable` and `concurrent-ruby` to clear known security advisories
- Remove the unused, stale RBS signatures under `sig/`
- Fix `imt sync all` not creating mods/tools for a `modinfo.json`/`toolinfo.json` found earlier in the same run; the new URL was only picked up on the next run
- Fix two sync hosts (or a sync and `imt add`/`remove`) running at once overwriting each other's changes to `meta/modinfo`, `meta/toolinfo`, `meta/repos` and the source maps
- Add a mass-delete brake: `imt sync mods`/`tools` refuses to delete more than 25% of a collection (at least 5 entries), or to empty it, unless run with `--force`
- Fix `imt sync` commands exiting 0 on failure; they now exit 1, and `imt sync all` runs every stage before exiting 1
- Fix `imt sync mods`/`tools` always printing "Success" at `-vv`, even when an update or delete failed
- Fix one `modinfo.json`/`toolinfo.json` whose body is not a JSON object (or whose entries are not objects) aborting the whole sync; it is now treated like invalid JSON and its existing entries are kept
- Fix a crash on a first run against an empty database (missing `meta` documents)
- Fix source URLs losing their query string, and a malformed URL crashing the sync instead of being skipped
- Save recorded sources even when a sync fails partway through, so the next run can still protect those entries
- Fix `imt remove repos` removing the wrong entries
  - Matches a repo's `modinfo.json`/`toolinfo.json` URLs only on the GitHub host and exact `owner/repo` (case-insensitive); before, a same-named subdirectory in someone else's repo matched
  - Deletes only the mods and tools that `meta/mod_sources`/`meta/tool_sources` attribute to the repo's URLs (falling back to name and author for entries with no recorded source), so a fork publishing the same name and author keeps its entry
  - Cascades for repos stored as full URLs too
  - Keeps the repo entry and exits 1 when any delete or fetch fails, so the removal can be retried
- Tighten validation: file types, URLs (http/https with a host) and versions are now matched exactly; input the old checks accepted (`notzipx`, `javascript:` URLs, `1.0 garbage`) is a warning for now and will become an error in a future release
- Fix non-string values (`"version": 1.0`, `"name": 5`, numeric URLs, `files` that is not an object) crashing validation; they are now reported as errors
- Fix `Toolinfo#validate` not being public, and unknown attribute names on mod/tool entries silently returning nil instead of raising
- Fix `imt list mods`/`tools` crashing on `--filter` values containing regex characters, on empty or non-text fields, on `--sort files` or fields missing from some entries, and on entries with no update time; filters are now case-insensitive substring matches and errors go to stderr
- Fix `imt validate` crashing on an empty list, and `imt` crashing on a malformed config file (it now prints an error and exits 1)
- Fix the GitHub file cache returning a top-level listing for recursive or sub-path lookups, and `find("modinfo.json")` matching names like `my_modinfo.json.bak`
- CI now also runs RuboCop and `bundler-audit`, and pins its GitHub Actions to commit SHAs; add a `.rubocop.yml` matching the project's style (existing size/complexity offenses are recorded in `.rubocop_todo.yml`)
- Update `rubocop-rspec` to 3.x (2.x no longer loads with current RuboCop)
- Fix `imt add`: `mod` validates every entry before writing anything and reports bad JSON or a missing `mods` list; every `add` command exits 1 on failure; add `--dry-run`

### v2.7.0 - 2026-10-30

- Fix sync deleting a source's mods and tools when its `modinfo.json`/`toolinfo.json` could not be read (#16)
  - Authors still control removal: if a file is removed or renamed (HTTP 404 or 410), its entries are deleted as before
  - A transient failure (timeout, network/DNS/TLS error, 5xx, 403/429 rate limit, any other unexpected status) or invalid JSON no longer deletes that source's entries; deletions are blocked per source, so other authors' removals still go through, and a warning lists every kept entry and why
  - Sync records which file each mod and tool came from in new internal Firestore docs, `meta/mod_sources` and `meta/tool_sources` (the mods and tools docs are unchanged). An entry with no recorded source yet, such as on the first run after upgrading, is kept while any source fails transiently
  - Invalid JSON is reported with a loud warning so an author mid-edit is not wiped
- Fix a repository whose GitHub search fails transiently (rate limit, 5xx, network error) aborting `imt sync modinfo`/`toolinfo`; it is now skipped with a warning and its existing list entries are kept (#16)
- Change `imt sync cleanup` to keep the oldest duplicate, whose ID clients already store, instead of the most recently updated one (#16)
  - The most recently updated duplicate's data is copied onto the kept entry before the others are deleted
  - `--dry-run` shows what would be kept, copied and deleted
- Give new mods and tools deterministic document IDs derived from type, author and name, so an entry that is deleted and re-added keeps its ID (#16)
  - Existing documents keep their current IDs

### v2.6.0 - 2026-03-04

- Add `imt sync cleanup` command to remove duplicate entries from mods and tools collections
  - Groups entries by name+author and keeps the most recently updated
  - Supports `--dry-run` to preview what would be deleted
- Fix `find_info` to match by both name AND author, not just name
  - Previously, mods/tools with the same name but different authors could cause incorrect deletion logic
  - Now consistent with `info_array` deduplication and `find_by_type` lookups

### v2.5.2 - 2026-02-09

- Fix duplicate entries created during sync operations
  - Update Firestore cache after creating new documents to prevent duplicate creation within the same sync run
  - Deduplicate info arrays by name+author before processing (handles duplicate/equivalent modinfo URLs)
  - Strip empty file entries (e.g., `pak: ""`) from database writes
  - Fix `id=` setter on Baseinfo (was silently no-op via method_missing, now uses attr_accessor)

### v2.5.1 - 2026-01-31

- Fix `imt remove repo` failing to find repositories stored as full URLs
  - Now checks for exact match first (handles full URLs), then falls back to stripped format

### v2.5.0 - 2026-01-12

- Add automatic conversion of GitHub URLs to `raw.githubusercontent.com` format during sync
  - Converts both `/blob/` and `/raw/` URLs from `github.com` domain
  - Applies to all file URLs in modinfo and toolinfo files
  - Also applies to imageURL and readmeURL fields
  - Warnings added to alert users to update source files
  - Ensures compatibility with GitHub's current raw file hosting on `raw.githubusercontent.com`

### v2.4.1 - 2026-01-12

- Fix JSON parsing error messages during sync to show concise error instead of full stack trace
- Include URL in JSON parsing error messages to identify which repository has invalid JSON

### v2.4.0 - 2026-01-11

- Add `imt remove mod` command to remove entries from `mods` collection
- Add `imt remove tool` command to remove entries from `tools` collection
- Add cascade delete to `imt remove repos` (enabled by default via `--cascade` flag)
  - When removing a repository, also removes associated modinfo, toolinfo, mods, and tools entries
- Improvements to cascade delete functionality:
  - Fix URL matching to prevent false matches (e.g., "owner/repo" no longer matches "owner/repo-fork")
  - Handle multiple entities with same name and author (deletes all matches)
  - Improve error handling with specific exception types and comprehensive reporting
  - Track and report both fetch failures and delete failures with detailed summaries
  - Enhanced dry-run output showing all entities that would be deleted
  - Add Firestore cache invalidation for mod/tool deletions

### v2.3.0 - 2025-12-18

- Add comprehensive test coverage
- Fix sync 404 errors

### v2.1 - 2023-02-11

- Remove support for `fileType` and `fileURL` in `modinfo.json` files
- bugfixes

### v2.0 - 2023-02-03

- Converts to new `files` object, replacing fileType and fileURL

### v1.9 - 2023-01-28

- Renamed `Progs` to `Tools`

### v1.8 - 2023-01-27

- Added support for `proginfo.json` files
- Refactored to better utilize caching

### v1.7 - 2023-01-20

- Added `validation` command
- Added `--dry-run` to `sync` commands

### v1.6 - 2023-01-15

- Added `--check` to `sync mods` to check for updates without downloading
- Added support for `readmeURL` in `modinfo.json`

### v1.5 - 2023-01-08

- Moved source into the DonovanMods Github organization
- Added `long_description` to `modinfo.json`
- Added `imageURL` to `modinfo.json`
- bugfixes

### v1.4 - 2023-01-03

**BREAKING CHANGES!**

You'll need to move your ENV variables to a config file. See the README for more details.

- Read configuration from `~/.imtconfig.json`
- bugfixes

### v1.3 - 2023-01-02

- First public release
- Added sorting and filtering to the `list mods` command
- Bugfixes

### v1.2 - 2023-01 _[Unreleased]_

- initial `sync mods` working functionality
- Bugfixes

### v1.1 - 2022-12 _[Unreleased]_

- Initial alpha release

### v1.0 - 2022-12 _[Unreleased]_

- Development
