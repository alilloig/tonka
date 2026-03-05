# Tonka for Dummies

A beginner's guide to running Claude Code in an ephemeral macOS sandbox.

---

## 1. What Is Tonka?

Tonka creates ephemeral macOS virtual machines using [Tart](https://tart.run/) so you can run Claude Code with `--dangerously-skip-permissions` without any risk to your host machine. Code lives entirely inside the VM — nothing can escape.

The core problem: Claude Code's `--dangerously-skip-permissions` flag is powerful but dangerous on a real machine. Tonka wraps it in a disposable VM so Claude can do whatever it needs — install packages, modify files, run arbitrary commands — without risk to your host. When you're done, stop or delete the VM.

After following this guide, you will have a running macOS VM with your repos, dotfiles, and Claude Code ready to go. You create "projects" (git worktrees) inside the VM and launch Claude in them.

---

## 2. How It All Fits Together

Tonka uses a two-tier VM model:

```
┌─────────────────────────────────────────────────┐
│  HOST (your Mac)                                │
│                                                 │
│  ~/.tonka.conf        Config file               │
│  ~/.ssh/id_ed25519_tonka   SSH key (auto-gen)   │
│  ./tonka              The entire CLI            │
│                                                 │
│         ┌───── SSH (ed25519 key) ─────┐         │
│         │                             │         │
│         ▼                             │         │
│  ┌─────────────┐   tart clone   ┌────┴────────┐│
│  │ tonka-base  │ ──────────────▶│  tonka-vm   ││
│  │ (template)  │                │  (working)  ││
│  │             │                │             ││
│  │ - Homebrew  │                │ ~/repos/    ││
│  │ - gh CLI    │                │ ~/projects/ ││
│  │ - Claude CLI│                │ - worktrees ││
│  │ - dotfiles  │                │ - Claude    ││
│  │ - tools     │                │   sessions  ││
│  └─────────────┘                └─────────────┘│
│  Never used directly.           This is where  │
│  Built once via                 you work.      │
│  rebuild-base.                                  │
└─────────────────────────────────────────────────┘
```

**tonka-base** is the template VM. It gets built once with `tonka rebuild-base`. It contains Homebrew, the GitHub CLI, Claude CLI, your dotfiles, and any tools you configure. It is never used directly.

**tonka-vm** is cloned from `tonka-base` the first time you need it. It holds your git repos (`~/repos/`) and project worktrees (`~/projects/`). All Claude Code sessions run here.

**Communication** between host and VM is exclusively via SSH, using a dedicated ed25519 key at `~/.ssh/id_ed25519_tonka` (auto-generated on first `rebuild-base`).

---

## 3. Prerequisites

You need:

- **macOS with Apple Silicon** — Tart only runs on M-series Macs
- **Tart** — the VM manager:
  ```bash
  brew install cirruslabs/cli/tart
  ```
- **sshpass** — needed during base VM setup for initial SSH with default credentials:
  ```bash
  brew install hudochenkov/sshpass/sshpass
  ```
- **GitHub CLI** — authenticated on your host machine:
  ```bash
  brew install gh
  gh auth login
  ```
- **(Optional) A dotfiles repo on GitHub** — with a `setup.sh` at the root

---

## 4. Configuration

Create a configuration file at `~/.tonka.conf`:

```bash
# Required if you want dotfiles installed in the VM
# Both SSH and HTTPS URLs work — SSH URLs are auto-converted to HTTPS for cloning
TONKA_DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"

# Optional: language toolchains to install inside the VM
# Choices: rust, go, nodejs, python (space-separated)
TONKA_TOOLS="nodejs rust"
```

You can also set these as environment variables instead of putting them in `~/.tonka.conf`. The config file is simply sourced as a shell script. See the full [Configuration Reference](#configuration-reference) at the end.

---

## 5. Getting Tonka on Your PATH

Clone the repo and make `tonka` accessible. Pick one approach:

**Option A — Symlink (recommended):**
```bash
git clone https://github.com/yourusername/tonka.git ~/tonka
ln -s ~/tonka/tonka /usr/local/bin/tonka
```

**Option B — Add to PATH:**
```bash
git clone https://github.com/yourusername/tonka.git ~/tonka
echo 'export PATH="$HOME/tonka:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Verify it works:
```bash
tonka --help
```

---

## 6. Building Your First Base VM

```bash
tonka rebuild-base
```

This takes a while (downloading a macOS image, installing Homebrew, etc.). Here's what happens behind the scenes:

1. **Downloads a macOS image** from the configured `TONKA_BASE_IMAGE` (a macOS Tahoe + Xcode image by default)
2. **Creates a user** matching your host username (so file paths feel familiar)
3. **Installs Homebrew** and every formula/cask you have installed on your host Mac
4. **Installs language toolchains** from `TONKA_TOOLS` (if configured)
5. **Installs the Claude CLI** (`~/.local/bin/claude`)
6. **Copies your Claude settings** (settings.json, skills) into the VM
7. **Configures GitHub auth** using your `gh` token so `git clone/push` work inside the VM
8. **Clones your dotfiles** to `~/.dotfiles` and runs `setup.sh` (if `TONKA_DOTFILES_REPO` is set) — SSH URLs are automatically converted to HTTPS so cloning uses the `gh` credential helper instead of SSH keys
9. **Shuts down** — the base VM is now a frozen template

You only need to run `rebuild-base` once, or when you change your config.

---

## 7. Adding a Repo

To work on a project, first add its repo to the VM:

```bash
tonka new-repo ~/dev/myproject
```

What this does:
- Reads the `origin` remote URL from your local repo
- Converts SSH remotes (`git@github.com:...`) to HTTPS (needed for the `gh` credential helper)
- Clones the repo into `~/repos/myproject` inside the VM

> **Note:** This clones the remote, not your local copy. Any unpushed local changes won't be in the VM. Push first!

You can add multiple repos:
```bash
tonka new-repo ~/dev/project-alpha
tonka new-repo ~/dev/project-beta
```

---

## 8. Creating a Project & Launching Claude

Now create a project (a git worktree) and launch Claude:

```bash
tonka new my-feature myproject
```

This:
1. Ensures the VM is running (starts it if needed)
2. Syncs your latest Claude settings, skills, plugins, and credentials to the VM
3. Creates a git worktree at `~/projects/my-feature` (branched from `myproject`)
4. SSHs into the VM and launches `claude --dangerously-skip-permissions`

Claude runs in full autonomous mode. When Claude exits, you stay in the VM shell — explore, run tests, inspect files. Press **Ctrl-D** to leave the VM.

If the repo name is omitted and you only have one repo, Tonka picks it automatically:
```bash
tonka new my-feature
```

---

## 9. Day-to-Day Workflow

Here's what a typical day looks like:

```bash
# One-time setup (already done above)
tonka rebuild-base
tonka new-repo ~/dev/myproject

# Daily work
tonka new fix-login-bug myproject   # new worktree + Claude
# ... Claude does its thing ...
# Ctrl-D to leave

tonka cl fix-login-bug              # re-enter the same project later
tonka                               # or just pick from a list

# Review a PR in isolation
tonka pr 42 myproject

# Get VM changes back to your host
cd ~/dev/myproject
tonka sync
git log tonka/fix-login-bug

# View a diff without syncing branches
cd ~/dev/myproject
tonka diff fix-login-bug

# Open in Cursor/VS Code
tonka cursor fix-login-bug

# Housekeeping
tonka cleanup                       # remove merged worktrees
tonka stop                          # stop the VM when done for the day
```

---

## 10. Writing a `setup.sh` for Your Dotfiles

If you set `TONKA_DOTFILES_REPO`, Tonka clones it to `~/.dotfiles` inside the VM and runs `setup.sh`. This section explains how to write one that works with Tonka.

### Execution Context

When `setup.sh` runs:
- **Shell**: `/bin/bash` (macOS bash 3.2 — **not** zsh, not bash 5)
- **User**: Your user (not root — but `sudo` is available with NOPASSWD)
- **Working directory**: `~/.dotfiles` (the root of your cloned dotfiles repo)
- **What's already installed**: Homebrew, `git`, `gh`, your host brew packages, Claude CLI, and any `TONKA_TOOLS`
- **What's NOT available**: GUI apps aren't usable (VM runs headless with `--no-graphics`)

### Template

```bash
#!/bin/bash
# setup.sh — Dotfiles setup script for Tonka VMs (and anywhere else)
# Runs under bash 3.2 on macOS. No bashisms beyond 3.2!

set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"

# ─── Helper: back up existing file/symlink, then create symlink ───
backup_and_link() {
    local source="$1"
    local target="$2"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        return
    fi

    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "  Backing up $target → ${target}.bak"
        mv "$target" "${target}.bak"
    fi

    if [ -L "$target" ]; then
        rm "$target"
    fi

    echo "  Linking $source → $target"
    ln -s "$source" "$target"
}

# ─── Symlink dotfiles ───
echo "Linking dotfiles..."
mkdir -p "$HOME/.config"

backup_and_link "$DOTFILES_DIR/zshrc"     "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/gitconfig" "$HOME/.gitconfig"
# Add your own:
# backup_and_link "$DOTFILES_DIR/config/nvim" "$HOME/.config/nvim"

echo "Done!"
```

### Key Rules

**DO:**
- Make the script **idempotent** — running it twice produces the same result. This matters because `rebuild-base` runs it every time.
- Use the `backup_and_link` pattern to avoid overwriting existing files.
- Keep it fast — this runs during `rebuild-base`, which is already slow.

**DON'T:**
- **Don't install packages** — Homebrew and your host packages are already installed by Tonka before `setup.sh` runs.
- **Don't use bash 4+ features** — no associative arrays (`declare -A`), no `${var,,}` lowercasing, no `mapfile`/`readarray`. macOS ships bash 3.2.

---

## 11. Rebuilding & What Gets Destroyed

Run `tonka rebuild-base` when you:
- Change `~/.tonka.conf` (new tools, different base image, etc.)
- Update your dotfiles and want a fresh base
- Install or remove brew packages on your host (they mirror into the VM)
- Something is broken and you want a clean slate

| What | Destroyed? |
|---|---|
| `tonka-base` | Always (rebuilt from scratch) |
| `tonka-vm` | Only if you say "yes" at the prompt |
| Repos in `~/repos/` | Only if tonka-vm is rebuilt |
| Projects in `~/projects/` | Only if tonka-vm is rebuilt |
| Code pushed to GitHub | Never — it's on the remote |

**Always push your work before rebuilding** if there's any chance you'll rebuild `tonka-vm`.

---

## 12. Troubleshooting

**SSH timeout during `rebuild-base`** — The VM takes ~30 seconds to boot. If SSH can't connect after 60 seconds, the build fails. Try `tart delete tonka-base` then `tonka rebuild-base`.

**Brew install failures** — Some host packages can't be installed in the VM (architecture differences, macOS version mismatches). Tonka uses `|| true` so these don't stop the build, but you'll see warnings. The important tools (`git`, `gh`) are installed separately.

**`No repos found`** — Add a repo first with `tonka new-repo <path>`.

**Claude won't start / credentials missing** — Tonka syncs credentials from your host every time you run `tonka new` or `tonka cl`. Make sure `gh auth status` works and `claude --version` runs on your host.

**Settings not syncing** — Sync only runs during `tonka new` and `tonka cl`. If you changed settings mid-session, exit and re-enter with `tonka cl <project>`.

**VM IP changes after restart** — Normal. Tonka looks up the IP dynamically with `tart ip`.

**Git push/pull fails inside the VM** — Tonka converts SSH remote URLs to HTTPS and uses `gh auth git-credential`. If auth fails, check that `gh auth status` works on your host.

**Dotfiles `setup.sh` failed** — SSH in and debug:
```bash
tonka sh
cd ~/.dotfiles
bash -x setup.sh       # run with debug tracing
```

---

## Appendix A: All Commands

| Command | Description |
|---|---|
| `tonka` | Launch Claude in a project (prompts to select if multiple) |
| `tonka new <project> [repo]` | Create a new worktree + launch Claude |
| `tonka cl <project>` | Launch Claude in an existing project |
| `tonka pr <pr#> [repo]` | Check out a GitHub PR and launch Claude in it |
| `tonka new-repo <path>` | Clone a local repo's remote into the VM |
| `tonka sh [project]` | SSH into the VM (optionally into a project directory) |
| `tonka cursor <project>` | Open a project in Cursor/VS Code via SSH Remote |
| `tonka cp <src> [dest]` | Copy a file or directory into the VM (dest defaults to `~`) |
| `tonka sync` | Fetch VM branches into your local repo as `tonka/<branch>` remotes (run from inside the local repo) |
| `tonka diff <project>` | Sync and show diff of project branch vs `origin/main` (run from local repo) |
| `tonka difftool <project>` | Same as `diff` but opens your configured difftool |
| `tonka list` | List all repos and projects inside the VM |
| `tonka cleanup` | Prune merged worktrees across all repos |
| `tonka start` | Start the VM (if stopped) |
| `tonka stop` | Stop the VM |
| `tonka rebuild-base` | Rebuild the base VM from scratch |

---

## Appendix B: Configuration Reference

Config file: `~/.tonka.conf` (sourced as a shell script). All variables can also be set as environment variables.

| Variable | Required | Default | Description |
|---|---|---|---|
| `TONKA_BASE_IMAGE` | No | `ghcr.io/cirruslabs/macos-tahoe-xcode:latest` | Tart image for the base VM |
| `TONKA_CPU` | No | Host CPU count (`sysctl -n hw.ncpu`) | Number of VM CPUs |
| `TONKA_MEMORY` | No | 5/8 of host RAM in MB | VM memory in MB |
| `TONKA_DISK_SIZE` | No | (Tart default) | VM disk size in GB (e.g., `512`) |
| `TONKA_DOTFILES_REPO` | No | (none) | Git URL of your dotfiles repo. Must have `setup.sh` at root |
| `TONKA_TOOLS` | No | (none) | Space-separated list: `rust`, `go`, `nodejs`, `python` |
| `GITHUB_TOKEN` | No | Auto-detected from `gh auth token` | Passed to VM for GitHub CLI authentication |

---

## Appendix C: How It Boots (Under the Hood)

When you run any command that needs the VM, Tonka goes through these phases:

### Phase 1 — Ensure the base VM exists
If `tonka-base` does not exist, Tonka runs the full `rebuild-base` flow: clone the Tart image, boot it, SSH in with `sshpass` (admin/admin), run `guest/install.sh` to create your user, install tools, configure auth, and clone dotfiles.

### Phase 2 — Clone the working VM
If `tonka-vm` does not exist, Tonka clones it from `tonka-base` and sets CPU/memory/disk according to your config.

### Phase 3 — Start and wait for SSH
If `tonka-vm` is not running, Tonka starts it headless, waits 15 seconds for initial boot, then polls up to 60 seconds for an IP address, then up to 60 seconds for SSH. Once SSH is ready, it updates `~/.ssh/config` with the VM's current IP under the host alias `tonka`.

### Phase 4 — Sync settings (on `new` and `cl` commands)
Before launching Claude, Tonka syncs these items from host to VM (skipping unchanged items via MD5 hash comparison):
- `~/.claude/settings.json`
- `~/.claude/skills/` (entire directory)
- `~/.config/gh/hosts.yml` (GitHub CLI credentials)
- Git credential helper configuration
- Claude plugins from `~/.claude/plugins/installed_plugins.json`
- `~/.claude.json` (onboarding state — only if missing in VM)
- macOS Keychain entry `"Claude Code-credentials"` → `~/.claude/.credentials.json`

---

## Appendix D: Glossary

**Tart** — An open-source macOS VM manager by Cirrus Labs that runs Apple Silicon VMs natively using the macOS Virtualization framework.

**Worktree** — A git feature that lets you check out multiple branches simultaneously in separate directories, all sharing the same `.git` data. Tonka uses worktrees to create isolated project directories from a single cloned repo.

**Base VM (`tonka-base`)** — The template virtual machine. Contains all installed tools and configuration. Never used directly — only cloned to create `tonka-vm`.

**Working VM (`tonka-vm`)** — The active virtual machine cloned from the base. Contains repos and project worktrees. This is where Claude Code sessions run.

**`--dangerously-skip-permissions`** — A Claude Code flag that bypasses all tool-use permission prompts. Tonka makes this safe by confining execution to a disposable VM.

---

## Appendix E: Important Files

| File | Description |
|---|---|
| `tonka` | The entire CLI (~900 lines of bash). All commands are `cmd_*` functions dispatched from `main()` |
| `guest/install.sh` | Runs inside the base VM during `rebuild-base`. Creates the user, installs tools, configures auth, clones dotfiles |
| `guest/configure.sh` | Dead code. Legacy script from a shared-volume approach. Never called — safe to ignore |
| `CLAUDE.md` | Architecture docs and development guidelines for Claude Code |
| `README.md` | Project overview, prerequisites, and usage examples |
| `~/.tonka.conf` | User config file (not in the repo — lives on your machine) |
| `~/.ssh/id_ed25519_tonka` | SSH key for host↔VM communication (auto-generated, not in the repo) |
