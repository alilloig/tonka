#!/bin/bash
# install.sh - Base VM setup script
# Run on the base VM to install all required tools and configure the tonka user
#
# Environment variables:
#   TONKA_DOTFILES_REPO - Git URL of dotfiles repo (must have setup.sh at root)
#   GITHUB_TOKEN - GitHub token for git authentication
#   TONKA_TOOLS - Space-separated list of tools to install (rust, go, nodejs, python)
#   BREW_FORMULAE - Space-separated list of brew formulae from host
#   BREW_CASKS - Space-separated list of brew casks from host

set -euo pipefail

DOTFILES_REPO="${TONKA_DOTFILES_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
TONKA_TOOLS="${TONKA_TOOLS:-}"
BREW_FORMULAE="${BREW_FORMULAE:-}"
BREW_CASKS="${BREW_CASKS:-}"

echo "=== Tonka Base VM Setup ==="

# Create tonka user
echo "Creating tonka user..."
sudo sysadminctl -addUser tonka -fullName "Tonka User" -password tonka -admin

# Set up SSH directory for tonka user
echo "Configuring SSH access..."
sudo mkdir -p /Users/tonka/.ssh
sudo chmod 700 /Users/tonka/.ssh

# Copy SSH keys
if [[ -f /tmp/tonka.pub ]]; then
    sudo cp /tmp/tonka.pub /Users/tonka/.ssh/authorized_keys
    sudo chmod 600 /Users/tonka/.ssh/authorized_keys
fi
if [[ -f /tmp/tonka_key ]]; then
    sudo cp /tmp/tonka_key /Users/tonka/.ssh/id_ed25519
    sudo cp /tmp/tonka.pub /Users/tonka/.ssh/id_ed25519.pub
    sudo chmod 600 /Users/tonka/.ssh/id_ed25519
    sudo chmod 644 /Users/tonka/.ssh/id_ed25519.pub
fi
sudo chown -R tonka:staff /Users/tonka/.ssh

# Add github.com to known_hosts
sudo -u tonka -H bash -c 'ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null'

# Enable passwordless sudo for tonka user
echo "Enabling passwordless sudo for tonka..."
echo "tonka ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/tonka

# Install Homebrew as tonka user
echo "Installing Homebrew..."
sudo -u tonka -H /bin/bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Add brew to path for subsequent commands
export PATH="/opt/homebrew/bin:$PATH"

# Install essential tools via brew
echo "Installing essential tools..."
sudo -u tonka -H /opt/homebrew/bin/brew install git gh

# Install host brew formulae
if [[ -n "$BREW_FORMULAE" ]]; then
    echo "Installing host brew formulae..."
    # shellcheck disable=SC2086
    sudo -u tonka -H /opt/homebrew/bin/brew install $BREW_FORMULAE || true
fi

# Install host brew casks
if [[ -n "$BREW_CASKS" ]]; then
    echo "Installing host brew casks..."
    # shellcheck disable=SC2086
    sudo -u tonka -H /opt/homebrew/bin/brew install --cask $BREW_CASKS || true
fi

# Install TONKA_TOOLS
for tool in $TONKA_TOOLS; do
    case "$tool" in
        rust)
            echo "Installing Rust..."
            sudo -u tonka -H bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
            ;;
        go)
            echo "Installing Go..."
            sudo -u tonka -H /opt/homebrew/bin/brew install go
            ;;
        nodejs|node)
            echo "Installing Node.js..."
            sudo -u tonka -H /opt/homebrew/bin/brew install node
            ;;
        python)
            echo "Installing Python..."
            sudo -u tonka -H /opt/homebrew/bin/brew install python
            ;;
        *)
            echo "Unknown tool: $tool"
            ;;
    esac
done

# Install Claude CLI
echo "Installing Claude CLI..."
sudo -u tonka -H bash -c 'curl -fsSL https://claude.ai/install.sh | bash'

# Copy Claude settings if provided
if [[ -f /tmp/claude_settings.json ]]; then
    echo "Configuring Claude settings..."
    sudo mkdir -p /Users/tonka/.claude
    sudo cp /tmp/claude_settings.json /Users/tonka/.claude/settings.json
    sudo chown -R tonka:staff /Users/tonka/.claude
fi
if [[ -d /tmp/claude_skills ]]; then
    echo "Configuring Claude skills..."
    sudo mkdir -p /Users/tonka/.claude
    sudo cp -r /tmp/claude_skills /Users/tonka/.claude/skills
    sudo chown -R tonka:staff /Users/tonka/.claude
fi

# Enable Remote Login (SSH)
echo "Enabling SSH..."
sudo systemsetup -setremotelogin on

# Clone and run dotfiles if specified (uses SSH key for personal GitHub)
if [[ -n "$DOTFILES_REPO" ]]; then
    echo "Setting up dotfiles from: $DOTFILES_REPO"
    sudo -u tonka -H git clone "$DOTFILES_REPO" /Users/tonka/.dotfiles
    if [[ -f /Users/tonka/.dotfiles/setup.sh ]]; then
        echo "Running dotfiles setup.sh..."
        sudo -u tonka -H /bin/bash -c 'cd ~/.dotfiles && ./setup.sh'
    else
        echo "Warning: No setup.sh found in dotfiles repo"
    fi
else
    echo "No TONKA_DOTFILES_REPO set, skipping dotfiles setup"
fi

# Configure GitHub CLI and git credential helper (for work repos)
if [[ -n "$GITHUB_TOKEN" ]]; then
    echo "Configuring GitHub CLI authentication..."
    sudo -u tonka -H /bin/bash -c "echo '$GITHUB_TOKEN' | /opt/homebrew/bin/gh auth login --with-token"
    sudo -u tonka -H /opt/homebrew/bin/gh auth setup-git
fi

# Clean up
echo "Cleaning up..."
rm -f /tmp/tonka.pub /tmp/tonka_key /tmp/install.sh

echo "=== Base VM setup complete ==="
