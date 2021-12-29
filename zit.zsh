# Zit - minimal plugin manager for ZSH

# store all loaded modules to paths
export -Ua ZIT_MODULES_LOADED

# store all modules to be upgraded
export -Ua ZIT_MODULES_UPGRADE

# set variable below to change zit modules path
if [[ -z "${ZIT_MODULES_PATH}" ]]; then
  export ZIT_MODULES_PATH="${ZDOTDIR:-${HOME}}"
fi

_zit-param-validation() {
  local name="${1}"
  local param="${2}"

  if [[ -z "${param}" ]]; then
    printf '[zit] Missing argument: %s\n' "${name}"
    return 1
  fi
  return 0
}

# loader
zit-load() {
  _zit-param-validation 'Module directory' "${1}" || return 1
  _zit-param-validation '.zsh file' "${2}" || return 2

  local module_dir="${ZIT_MODULES_PATH}/${1}"
  local dot_zsh="${2}"

  # shellcheck source=/dev/null
  source "${module_dir}/${dot_zsh}" || return 255
  # added to global dir array for tracking
  ZIT_MODULES_LOADED+=("${module_dir}")
}

# installer
zit-install() {
  _zit-param-validation 'Git repo' "${1}" || return 1
  _zit-param-validation 'Module directory' "${2}" || return 2

  local git_url="${1}"
  local module_dir="${ZIT_MODULES_PATH}/${2}"

  # http://zsh.sourceforge.net/Doc/Release/Expansion.html#Parameter-Expansion
  # https://github.com/thiagokokada/zit#branch -> https://github.com/thiagokokada/zit
  local git_repo="${git_url%'#'*}"

  local git_branch="${git_url#*'#'}"
  # https://github.com/thiagokokada/zit -> master
  # https://github.com/thiagokokada/zit# -> master
  # https://github.com/thiagokokada/zit#branch -> branch
  if [[ -z "${git_branch}" ]] || [[ "${git_branch}" == "${git_url}" ]]; then
    git_branch="master"
  fi

  # clone module
  if [[ ! -d "${module_dir}" ]]; then
    printf 'Installing %s\n' "${module_dir}"
    git clone --recurse-submodules \
      "${git_repo}" -b "${git_branch}" "${module_dir}"
    printf '\n'
  fi
  # added to global dir array for updater
  [[ -z "${ZIT_DISABLE_UPGRADE}" ]] && ZIT_MODULES_UPGRADE+=("${module_dir}")
}

# do both above in one step
zit-install-load() {
  _zit-param-validation 'Git repo' "${1}" || return 1

  local git_repo="https://github.com/${1}"
  local module_dir="${2:-${git_repo##*/}}"
  local dot_zsh="${3:-${git_repo##*/}.plugin.zsh}"

  zit-install "${git_repo}" "${module_dir}"
  zit-load "${module_dir}" "${dot_zsh}"
}

# upgrade modules
zit-upgrade() {
  local module_dir

  for module_dir in "${ZIT_MODULES_UPGRADE[@]}"; do
    pushd "${module_dir}" > /dev/null || continue
    printf 'Updating %s\n' "${module_dir}"
    git pull
    printf '\n'
    popd > /dev/null || continue
  done
}
alias zit-update='zit-upgrade' # deprecated

# remove module
zit-remove() {
  _zit-param-validation 'Module directory' "${1}" || return 1

  local module_dir="${1}"
  local module_path="${ZIT_MODULES_PATH}/${module_dir}"

  if [[ -z "${ZIT_MODULES_UPGRADE[(r)${module_path}]}" ]]; then
    printf 'No module %s is installed.\n' "${module_dir}"
    return 255
  fi

  while true; do
    printf 'Really delete module %s? (y/n) ' "${module_dir}"
    read -r yn
    case $yn in
      [Yy]* ) rm -rf "${ZIT_MODULES_PATH:?}/${module_dir}"
              break;;
      [Nn]* ) break;;
      * ) echo 'Please answer (y)es or (n)o.';;
    esac
  done
}

alias zit-in='zit-install'
alias zit-lo='zit-load'
alias zit-il='zit-install-load'
alias zit-up='zit-upgrade'
alias zit-rm='zit-remove'

# vim: ft=zsh
