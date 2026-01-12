# Change Log

All notable changes to this project will be documented in this file.

## History (reverse chronological order)

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
