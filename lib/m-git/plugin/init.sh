if [ -n "$BASH_VERSION" ]; then
  plugin_root="$(dirname "${BASH_SOURCE[0]}")"
  source "$plugin_root/completion.bash"

elif [ -n "$ZSH_VERSION" ]; then
  plugin_root="$(dirname "$0")"
  source "$plugin_root/completion.zsh"
fi
