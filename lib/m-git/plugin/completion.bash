_mgit_completion() {
  COMPREPLY=()

  local completions word argc
  word="${COMP_WORDS[COMP_CWORD]}"
  argc=${#COMP_WORDS[@]}

  if [[ $argc < 2 ]]; then
    return
  elif [[ $argc == 2 ]]; then
    completions="$(mgit script --commands)"
  elif [[ $argc > 2 ]]; then
    completions="$(mgit script --list --all --commands ${COMP_WORDS[1]})"
  fi

  COMPREPLY=( $(compgen -W "$completions" -- "$word") )
}

complete -F _mgit_completion mgit
