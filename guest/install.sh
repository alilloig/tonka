#!/bin/bash
# install.sh - Base VM setup script
# Run on the base VM to install all required tools and configure the tonka user
#
# Environment variables:
#   TONKA_DOTFILES_REPO - Git URL of dotfiles repo (must have setup.sh at root)
#   GITHUB_TOKEN - GitHub token for git authentication

set -euo pipefail

DOTFILES_REPO="${TONKA_DOTFILES_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

echo "=== Tonka Base VM Setup ==="

# Create tonka user
echo "Creating tonka user..."
sudo sysadminctl -addUser tonka -fullName "Tonka User" -password tonka -admin

# Set up SSH directory for tonka user
echo "Configuring SSH access..."
sudo mkdir -p /Users/tonka/.ssh
sudo chmod 700 /Users/tonka/.ssh

# Copy SSH public key
if [[ -f /tmp/tonka.pub ]]; then
    sudo cp /tmp/tonka.pub /Users/tonka/.ssh/authorized_keys
    sudo chmod 600 /Users/tonka/.ssh/authorized_keys
    sudo chown -R tonka:staff /Users/tonka/.ssh
fi

# Enable passwordless sudo for tonka user
echo "Enabling passwordless sudo for tonka..."
echo "tonka ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/tonka

# Install Homebrew as tonka user
echo "Installing Homebrew..."
sudo -u tonka -H /bin/bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Add brew to path for subsequent commands
export PATH="/opt/homebrew/bin:$PATH"

# Install essential tools via brew (minimal set - dotfiles can add more)
echo "Installing development tools..."
sudo -u tonka -H /opt/homebrew/bin/brew install git gh

# Enable Remote Login (SSH)
echo "Enabling SSH..."
sudo systemsetup -setremotelogin on

# Configure GitHub CLI and git credential helper
if [[ -n "$GITHUB_TOKEN" ]]; then
    echo "Configuring GitHub authentication..."
    sudo -u tonka -H /bin/bash -c "echo '$GITHUB_TOKEN' | /opt/homebrew/bin/gh auth login --with-token"
    sudo -u tonka -H /opt/homebrew/bin/gh auth setup-git
fi

# Configure git to use HTTPS instead of SSH for GitHub
sudo -u tonka -H git config --global url."https://github.com/".insteadOf "git@github.com:"

# Clone and run dotfiles if specified
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

# Clean up
echo "Cleaning up..."
rm -f /tmp/tonka.pub /tmp/install.sh

echo "=== Base VM setup complete ==="
