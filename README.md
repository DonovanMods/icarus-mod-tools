# Icarus::Mod::Tools

a CLI tool for managing the Icarus Mods Database

## Requirements

To use this app, you'll need to obtain the following:

- A Github ACCESS_TOKEN (doesn't need access to any repos, this is used purely to make API calls)
- A Google Cloud Platform credentials `keyfile.json`
- Ruby 3.1 (or greater)

If you aren't sure how to obtain these credentials, please see:

- [Google Cloud Platform](https://cloud.google.com/docs/authentication/getting-started)
- [GitHub](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token)

I _highly_ recommend using WSL2 on Windows, or a Linux distro on your machine. This app has not been tested on Windows.

## Installation

`gem install Icarus-Mod-Tools`

## Configuration

Create a file called `.imtconfig.json` in your home directory with the following, replacing the CAPITALIZED values with the values provided by the above links:

```json
{
  "firebase": {
    "credentials": {
      "copy your Google Cloud Platform keyfile.json here and remove this line": null
    },
    "collections": {
      "modinfo": "meta/modinfo",
      "toolinfo": "meta/toolinfo",
      "repositories": "meta/repos",
      "mods": "mods",
      "tools": "tools"
    }
  },
  "github": {
    "token": "YOUR-GITHUB-TOKEN"
  }
}
```

_Hint: Copy the contents of your Google Cloud Platform `keyfile.json` into the `credentials` section of the above file._

## Usage

imt [options] [command]

### Commands

```sh
Commands:
  imt add             # Adds entries to the databases
  imt help [COMMAND]  # Describe available commands or one specific command
  imt list            # Lists the databases
  imt remove          # Removes entries from the databases
  imt sync            # Syncs the databases
  imt validate        # Validates various entries

Options:
  -C, [--config=CONFIG]            # Path to the config file
                                   # Default: /Users/dyoung/.imtconfig.json
  -V, [--version], [--no-version]  # Print the version and exit
```

#### `imt add`

```sh
Commands:
  imt add help [COMMAND]  # Describe subcommands or one specific subcommand
  imt add modinfo         # Adds an entry to 'meta/modinfo/list'
  imt add toolinfo        # Adds an entry to 'meta/toolinfo/list'
  imt add repos           # Adds an entry to 'meta/repos/list'
  imt add mod <filename>  # Adds an entry to 'mods' when given a modinfo.json file

Options:
  -C, [--config=CONFIG]            # Path to the config file
                                   # Default: /Users/dyoung/.imtconfig.json
  -V, [--version], [--no-version]  # Print the version and exit
  -v, [--verbose], [--no-verbose]  # Increase verbosity. May be repeated for even more verbosity.
                                   # Default: [true]
```

#### `imt list`

```sh
Commands:
  imt list help [COMMAND]  # Describe subcommands or one specific subcommand
  imt list modinfo         # Displays data from 'meta/modinfo/list'
  imt list mods            # Displays data from 'mods'
  imt list toolinfo        # Displays data from 'meta/toolinfo/list'
  imt list tools           # Displays data from 'tools'
  imt list repos           # Displays data from 'meta/repos/list'

Options:
  -C, [--config=CONFIG]            # Path to the config file
                                   # Default: /Users/dyoung/.imtconfig.json
  -V, [--version], [--no-version]  # Print the version and exit
  -v, [--verbose], [--no-verbose]  # Increase verbosity. May be repeated for even more verbosity.
                                   # Default: [true]
```

#### `imt remove`

```sh
Commands:
  imt remove help [COMMAND]  # Describe subcommands or one specific subcommand
  imt remove repos REPO      # Removes an entry from 'meta/repos/list'

Options:
  -C, [--config=CONFIG]            # Path to the config file
                                   # Default: /Users/dyoung/.imtconfig.json
  -V, [--version], [--no-version]  # Print the version and exit
  -v, [--verbose], [--no-verbose]  # Increase verbosity. May be repeated for even more verbosity.
                                   # Default: [true]
```

#### `imt sync`

```sh
Commands:
  imt sync all             # Run all sync jobs
  imt sync help [COMMAND]  # Describe subcommands or one specific subcommand
  imt sync modinfo         # Reads from 'meta/repos/list' and Syncs any modinfo files we find (github only for now)
  imt sync mods            # Reads from 'meta/modinfo/list' and updates the 'mods' database accordingly
  imt sync toolinfo        # Reads from 'meta/repos/list' and Syncs any toolinfo files we find (github only for now)
  imt sync tools           # Reads from 'meta/toolinfo/list' and updates the 'tools' database accordingly

Options:
  -C, [--config=CONFIG]            # Path to the config file
                                   # Default: /Users/dyoung/.imtconfig.json
  -V, [--version], [--no-version]  # Print the version and exit
  -v, [--verbose], [--no-verbose]  # Increase verbosity. May be repeated for even more verbosity.
                                   # Default: [true]
      [--dry-run], [--no-dry-run]  # Dry run (no changes will be made)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/DonovanMods/icarus-mod-tools>.
