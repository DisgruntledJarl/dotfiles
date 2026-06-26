#!/bin/bash
set -euo pipefail

# === Prompt for details ===
read -p "Enter your email for SSH key and git config: " EMAIL
read -p "Enter your git username: " GIT_USERNAME
echo ""

# === SSH Setup ===
echo "=== Setting up SSH ==="
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ ! -f "$HOME/.ssh/github" ]; then
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$HOME/.ssh/github" -N ""

  cat > "$HOME/.ssh/config" << EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github
  AddKeysToAgent yes
EOF
  chmod 600 "$HOME/.ssh/config"

  eval "$(ssh-agent -s)"
  ssh-add "$HOME/.ssh/github"

  echo ""
  echo "Add this public key to GitHub before continuing:"
  echo "https://github.com/settings/ssh/new"
  echo ""
  cat "$HOME/.ssh/github.pub"
  echo ""
  read -p "Press Enter once you've added the key..."
else
  echo "SSH key already exists, skipping generation."
  eval "$(ssh-agent -s)"
  ssh-add "$HOME/.ssh/github"
fi

# === Verify GitHub connection ===
echo ""
echo "=== Verifying GitHub SSH connection ==="
ssh -T git@github.com 2>&1 || true

# === Clone dotfiles ===
DOTFILES_DIR="$HOME/dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
  echo ""
  echo "=== Cloning dotfiles ==="
  git clone git@github.com:disgruntledjarl/dotfiles.git "$DOTFILES_DIR"
else
  echo "Dotfiles repo already exists, skipping clone."
fi

# === Git config ===
echo ""
echo "=== Configuring git ==="
git config --global user.email "$EMAIL"
git config --global user.name "$GIT_USERNAME"
git config --global core.editor "code --wait"
git config --global core.autocrlf input
git config --global pull.rebase false
git config --global push.autoSetupRemote true

# === Symlink dotfiles ===
echo ""
echo "=== Symlinking dotfiles ==="
for file in "$DOTFILES_DIR/home"/.[^.]*; do
  filename=$(basename "$file")
  target="$HOME/$filename"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "Backing up existing $filename to $filename.bak"
    mv "$target" "$target.bak"
  fi

  ln -sf "$file" "$target"
  echo "Linked $filename"
done

# === WSL config ===
echo ""
echo "=== Writing WSL config ==="
sudo ln -sf "$DOTFILES_DIR/wsl.conf" "/etc/wsl.conf"

# === Install packages ===
echo ""
echo "=== Installing packages ==="
sudo apt update && sudo apt upgrade -y
sudo apt install -y $(cat "$DOTFILES_DIR/packages/apt.txt" | tr '\n' ' ')

# === Done ===
echo ""
source "$HOME/.bashrc"
echo "=== Done. Restart WSL for wsl.conf changes to take effect. ==="
