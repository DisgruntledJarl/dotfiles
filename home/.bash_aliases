# Add a dotfile to the repo and stage it
dotadd() {
  if [ -z "${1:-}" ]; then
    echo "Usage: dotadd <path to dotfile>"
    return 1
  fi

  local file
  file=$(realpath "$1")
  local filename
  filename=$(basename "$file")
  local DOTFILES_DIR="$HOME/dotfiles"
  local dest="$DOTFILES_DIR/home/$filename"

  cp "$file" "$dest"
  ln -sf "$dest" "$file"
  git -C "$DOTFILES_DIR" add "home/$filename"

  echo "Staged $filename — commit and push when ready:"
  echo "  git -C $DOTFILES_DIR commit -m 'dotfiles: add $filename'"
  echo "  git -C $DOTFILES_DIR push"
}

# Open Files with Zed which is installed in native Windows
alias zed="zed.exe --wsl $USER@Ubuntu"
