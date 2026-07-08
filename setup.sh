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
else
  echo "SSH key already exists, skipping generation."
fi

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

# === Verify GitHub connection, prompt to register key if needed ===
echo ""
echo "=== Verifying GitHub SSH connection ==="
until { ssh -T git@github.com 2>&1 || true; } | grep -q "successfully authenticated"; do
  echo ""
  echo "Add this public key to GitHub before continuing:"
  echo "https://github.com/settings/ssh/new"
  echo ""
  cat "$HOME/.ssh/github.pub"
  echo ""
  read -p "Press Enter once you've added the key..."
done
echo "GitHub SSH connection verified."

# === Clone dotfiles ===
REPO_DIR="$HOME/dotfiles"
DOTFILES_DIR="$REPO_DIR/dotfiles"

if [ ! -d "$REPO_DIR" ]; then
  echo ""
  echo "=== Cloning dotfiles ==="
  git clone "git@github.com:$GIT_USERNAME/dotfiles.git" "$REPO_DIR"
else
  echo "Dotfiles repo already exists, skipping clone."
fi

# === Git config ===
echo ""
echo "=== Configuring git ==="
git config --global user.email "$EMAIL"
git config --global user.name "$GIT_USERNAME"
git config --global github.user "$GIT_USERNAME"
git config --global core.editor "zed --wait"
git config --global core.autocrlf input
git config --global pull.rebase false
git config --global push.autoSetupRemote true

# === Symlink dotfiles ===
echo ""
echo "=== Symlinking dotfiles ==="

declare -A LINKS=(
  ["$DOTFILES_DIR/bash/.bashrc"]="$HOME/.bashrc"
  ["$DOTFILES_DIR/bash/.bash_aliases"]="$HOME/.bash_aliases"
  ["$DOTFILES_DIR/bash/.profile"]="$HOME/.profile"
  ["$DOTFILES_DIR/git"]="$HOME/.config/git"
  ["$DOTFILES_DIR/claude/settings.json"]="$HOME/.claude/settings.json"
  ["$DOTFILES_DIR/claude/statusline.sh"]="$HOME/.claude/statusline.sh"
  ["$DOTFILES_DIR/zed/settings.json"]="$HOME/.config/zed/settings.json"
)

for source in "${!LINKS[@]}"; do
  target="${LINKS[$source]}"
  mkdir -p "$(dirname "$target")"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "Backing up existing $target to $target.bak"
    mv "$target" "$target.bak"
  fi

  ln -sf "$source" "$target"
  echo "Linked $target -> $source"
done

# === WSL config ===
echo ""
echo "=== Writing WSL config ==="
sudo ln -sf "$DOTFILES_DIR/wsl/wsl.conf" "/etc/wsl.conf"

# === Install packages ===
echo ""
echo "=== Installing packages ==="
sudo apt update && sudo apt upgrade -y
sudo apt install -y $(cat "$REPO_DIR/packages/apt.txt" | tr '\n' ' ')

# === Install Claude Code ===
echo ""
echo "=== Installing Claude Code ==="
if command -v claude &> /dev/null; then
  echo "Claude Code already installed, skipping."
else
  curl -fsSL https://claude.ai/install.sh | bash
  if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi
fi

# === Done ===
echo ""
source "$HOME/.bashrc"
echo "=== Done. Restart WSL for wsl.conf changes to take effect. ==="
