# Tonka

*Making sandboxes fun*

![Tonka Truck](tonka.webp)

Ephemeral tart-based sandboxes for running Claude Code with `--dangerously-skip-permissions`.

## Features

- **No shared volumes** - Code lives entirely inside the VM for complete isolation
- **Automatic sync** of Claude settings, credentials, and plugins
- **GitHub credentials** synced via `gh` CLI
- **Dotfiles support** - Installs your dotfiles repo automatically
- **Configurable tools** - Install Rust, Go, Node.js, Python, and your brew packages

## Prerequisites

- [Tart](https://tart.run/) - macOS VM manager
- `sshpass` - For initial VM setup (`brew install hudochenkov/sshpass/sshpass`)
- A dotfiles repo with a `setup.sh` script (optional but recommended)

## Setup

Create a config file at `~/.tonka.conf`:

```bash
TONKA_DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"
```

Or set the environment variable:

```bash
export TONKA_DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"
```

Your dotfiles repo must have a `setup.sh` script at the root that installs Claude Code and any other tools you need.

## Usage

```bash
# Create new project sandbox from a local git repo
tonka new ~/dev/myproject

# Create with explicit name
tonka new ~/dev/myproject myproject-feature

# Start/stop/delete
tonka start myproject
tonka stop myproject
tonka delete myproject

# Connect
tonka shell myproject     # SSH into VM
tonka claude myproject    # Run Claude in project directory

# List projects
tonka list

# Rebuild base VM (after dotfiles changes)
tonka rebuild-base
```

## How It Works

1. **Base VM**: Created once with your dotfiles, tools, and Claude CLI installed
2. **Tonka VM**: Cloned from base, contains your repos and project worktrees
3. **Git Auth**: Uses `gh` CLI credential helper (synced from host)

## Configuration

Config file: `~/.tonka.conf` (sourced as shell script)

Variables (can be set in config file or environment):
- `TONKA_BASE_IMAGE` - Tart image to use for base VM (default: `ghcr.io/cirruslabs/macos-tahoe-xcode:latest`)
- `TONKA_DOTFILES_REPO` - Git URL of your dotfiles repo (must have `setup.sh` at root)
- `GITHUB_TOKEN` - Passed to VM for GitHub CLI authentication (auto-detected from `gh auth token` if not set)
