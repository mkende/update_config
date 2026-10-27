# update_config

`update_config` deploys configuration fragments (dotfiles, etc.) on the local
host or on remote hosts.

## Features

- **Fragments:** each fragment adds a block of content, between guard lines, to
  a target file, leaving the rest of the file untouched. A fragment can also
  replace the entire file.
- **Merged files:** for TOML, JSON, YAML and INI files that are rewritten by
  their program, the data of the fragment is merged into the existing data of
  the file instead.
- **Directives:** fragments can set the permissions of their target, require
  some conditions to be applied, run a command after an update, or be applied
  as root through `sudo`.
- **Commands:** a target can be read and written through commands (e.g.
  `crontab -l,crontab -`).
- **Remote hosts:** `update_config --pack | ssh host perl` applies all your
  fragments on a remote host, without installing anything there first.

## Installation

From CPAN, including the optional modules used by `MERGE`:

```sh
cpanm App::UpdateConfig Config::Tiny TOML::Tiny YAML::PP
```

Or as a standalone script, which installs its own dependencies when it first
runs:

```sh
curl -O https://raw.githubusercontent.com/mkende/update_config/main/script/update_config
chmod +x update_config
```

Then put your fragments in `~/.update_config` (or
`~/.config/update_config`) and run `update_config`.

## Documentation

The full documentation is available with `update_config --help` or on
[MetaCPAN](https://metacpan.org/dist/App-UpdateConfig/view/script/update_config).
