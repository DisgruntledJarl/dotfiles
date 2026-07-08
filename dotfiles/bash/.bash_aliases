# Add a dotfile to the repo (in its category folder), symlink it back, and stage it
dotadd() {
  if [ -z "${1:-}" ]; then
    echo "Usage: dotadd <path to dotfile>"
    return 1
  fi

  local target
  target=$(realpath "$1")
  local targetname
  targetname=$(basename "$target")
  local REPO_DIR="$HOME/dotfiles"
  local DOTFILES_DIR="$REPO_DIR/dotfiles"
  local setup_script="$REPO_DIR/setup.sh"

  echo "Categories:"
  local d
  for d in "$DOTFILES_DIR"/*/; do
    echo "  - $(basename "$d")"
  done

  local category relpath
  read -p "Category for $targetname: " category
  if [ -z "$category" ]; then
    echo "Category is required."
    return 1
  fi

  read -p "Path within $category/ [$targetname]: " relpath
  relpath="${relpath:-$targetname}"

  local dest="$DOTFILES_DIR/$category/$relpath"
  mkdir -p "$(dirname "$dest")"

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

  # Record the mapping in setup.sh's LINKS array so fresh machines pick it up too
  local source_expr="\$DOTFILES_DIR/$category/$relpath"
  local target_expr="${target/#$HOME/\$HOME}"

  if grep -qF "[\"$source_expr\"]" "$setup_script"; then
    echo "setup.sh already has an entry for $source_expr, leaving it as-is."
  else
    sed -i "/^declare -A LINKS=(/a\\  [\"$source_expr\"]=\"$target_expr\"" "$setup_script"
    echo "Added to LINKS in setup.sh: [\"$source_expr\"]=\"$target_expr\""
  fi

  # Stage in Git
  git -C "$REPO_DIR" add "dotfiles/$category/$relpath" "setup.sh"

  echo ""
  echo "Staged dotfiles/$category/$relpath and setup.sh — commit and push when ready:"
  echo "  git -C $REPO_DIR commit -m 'dotfiles: add $relpath'"
  echo "  git -C $REPO_DIR push"
}


# Clone git repos with just the name of the repository
gcl() {
    if [ -z "$1" ]; then
        echo "Usage: gcl repo-name"
        return 1
    fi
    git clone "git@github.com:$(git config --global user.name)/$1.git"
}
