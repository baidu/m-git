_mgit_completion() {

  if [[ ${#words[@]} == 2 ]]; then
    # Complete command
    completions="$(mgit script --commands)"
    reply=( "${(ps:\n:)completions}" )
  elif [[ ${#words[@]} > 2 ]]; then
    # Complete repo name and command's options
    # Array index starts at 1
    local cmd
    cmd=$words[2]
    completions="$(mgit script --all --list --commands $cmd)"
    reply=( "${(ps:\n:)completions}" )
  fi
}

compctl -K _mgit_completion mgit
