# Add a dotfile to the repo and stage it
dotadd() {
  if [ -z "${1:-}" ]; then
    echo "Usage: dotadd <path to dotfile>"
    return 1
  fi

  local target
  target=$(realpath "$1")
  local targetname
  targetname=$(basename "$target")
  local DOTFILES_DIR="$HOME/dotfiles"
  local dest="$DOTFILES_DIR/home/$targetname"

    # Copy recursively if it's a directory, otherwise copy normally
    if [ -d "$target" ]; then
      # Remove existing dest folder if it exists to avoid nested copies
      rm -rf "$dest"
      cp -r "$target" "$dest"
    else
      cp "$target" "$dest"
    fi

    # Re-create the symlink (works for both files and directories)
    # If it's a directory, we must remove the original to replace it with a symlink
    rm -rf "$target"
    ln -sf "$dest" "$target"

    # Stage in Git
    git -C "$DOTFILES_DIR" add "home/$target_name"

    echo "Staged $target_name — commit and push when ready:"
    echo "  git -C $DOTFILES_DIR commit -m 'dotfiles: add $target_name'"
    echo "  git -C $DOTFILES_DIR push"
}

# Open Files with Zed which is installed in native Windows
alias zed="zed.exe --wsl $USER@Ubuntu"

# Clone git repos with just the name of the repository
gcl() {
    if [ -z "$1" ]; then
        echo "Usage: gcl repo-name"
        return 1
    fi
    git clone "git@github.com:$(git config --global user.name)/$1.git"
}
