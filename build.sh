#!/usr/bin/env bash
set -eo pipefail
printf "      ___                       ___                 \n"
printf "     /\\__\\                     /\\  \\            \n"
printf "    /:/ _/_       ___         /::\\  \\             \n"
printf "   /:/ /\\__\\     /\\__\\       /:/\\:\\  \\       \n"
printf "  /:/ /:/  /    /:/__/      /:/  \\:\\  \\          \n"
printf " /:/_/:/  /    /::\\  \\     /:/__/ \\:\\__\\       \n"
printf " \\:\\/:/  /     \\/\\:\\  \\__  \\:\\  \\ /:/  /   \n"
printf "  \\::/__/         \\:\\/\\__\\  \\:\\  /:/  /      \n"
printf "   \\:\\  \\          \\::/  /   \\:\\/:/  /        \n"
printf "    \\:\\__\\         /:/  /     \\::/  /           \n"
printf "     \\/__/         \\/__/       \\/__/             \n"
printf "  FOUNDATION FOR INTERWALLET OPERABILITY            \n"

export CURRENT_WORKING_DIR=$(pwd)
export TEMP_DIR="${pwd}/tmp"
export NONINTERACTIVE=false

[[ -z "${ARCH}" ]] && export ARCH=$(uname)
if [[ -z "${NAME}" ]]; then
  if [[ $ARCH == "Linux" ]]; then
    [[ ! -e /etc/os-release ]] && echo "${COLOR_RED} - /etc/os-release not found! It seems you're attempting to use an unsupported Linux distribution.${COLOR_NC}" && exit 1
    # Obtain OS NAME, and VERSION
    . /etc/os-release
  elif [[ $ARCH == "Darwin" ]]; then
    export NAME=$(sw_vers -productName)
  else
    echo " ${COLOR_RED}- FIO is not supported for your Architecture!${COLOR_NC}" && exit 1
  fi
fi

# Setup yum and apt variables
if [[ $NAME =~ "Amazon Linux" ]] || [[ $NAME == "CentOS Linux" ]]; then
  if ! YUM=$(command -v yum 2>/dev/null); then echo "${COLOR_RED}YUM must be installed to compile FIO${COLOR_NC}" && exit 1; fi
elif [[ $NAME == "Ubuntu" ]]; then
  if ! APTGET=$(command -v apt-get 2>/dev/null); then echo "${COLOR_RED}APT-GET must be installed to compile FIO${COLOR_NC}" && exit 1; fi
fi

echo "Architecture: ${ARCH}"

ensure-sudo() {
  SUDO_LOCATION=$(command -v sudo)
  CURRENT_USER=$(whoami)
  ([[ $CURRENT_USER != "root" ]] && [[ -z $SUDO_LOCATION ]]) && echo "${COLOR_RED}Please build the 'sudo' command before proceeding!${COLOR_NC}" && exit 1
  true 1>/dev/null # Needed
}

ensure-homebrew() {
  echo "${COLOR_CYAN}[Ensuring HomeBrew installation]${COLOR_NC}"
  if ! BREW=$(command -v brew); then
    while true; do
      [[ $NONINTERACTIVE == false ]] && printf "${COLOR_YELLOW}Do you wish to install HomeBrew? (y/n)?${COLOR_NC}" && read -p " " PROCEED
      echo ""
      case $PROCEED in
      "") echo "What would you like to do?" ;;
      0 | true | [Yy]*)
        "${XCODESELECT}" --install 2>/dev/null || true
        if ! "${RUBY}" -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"; then
          echo "${COLOR_RED}Unable to install HomeBrew!${COLOR_NC}" && exit 1
        else BREW=$(command -v brew); fi
        break
        ;;
      1 | false | [Nn]*)
        echo "${COLOR_RED} - User aborted required HomeBrew installation.${COLOR_NC}"
        exit 1
        ;;
      *) echo "Please type 'y' for yes or 'n' for no." ;;
      esac
    done
  else
    echo " - HomeBrew installation found @ ${BREW}"
  fi
}

ensure-brew-packages() {
  ([[ -z "${1}" ]] || [[ ! -f "${1}" ]]) && echo "\$1 must be the location of your dependency file!" && exit 1
  DEPS_FILE="${TEMP_DIR}/$(basename ${1})"
  # Create temp file so we can add to it
  cat $1 >${DEPS_FILE}
  if [[ ! -z "${2}" ]]; then # Handle EXTRA_DEPS passed in and add them to temp DEPS_FILE
    printf "\n" >>${DEPS_FILE} # Avoid needing a new line at the end of deps files
    OLDIFS="$IFS"
    IFS=$''
    _2=("$(echo $2 | sed 's/-s /-s\n/g')")
    for ((i = 0; i < ${#_2[@]}; i++)); do echo "${_2[$i]}\n" | sed 's/-s\\n/-s/g' >>$DEPS_FILE; done
  fi
  echo "${COLOR_CYAN}[Ensuring HomeBrew dependencies]${COLOR_NC}"
  OLDIFS="$IFS"
  IFS=$','
  # || [[ -n "$nmae" ]]; needed to see last line of deps file (https://stackoverflow.com/questions/12916352/shell-script-read-missing-last-line)
  while read -r name path || [[ -n "$name" ]]; do
    if [[ -f $path ]] || [[ -d $path ]]; then
      echo " - ${name} ${COLOR_GREEN}ok${COLOR_NC}"
      continue
    fi
    # resolve conflict with homebrew glibtool and apple/gnu installs of libtool
    if [[ "${testee}" == "/usr/local/bin/glibtool" ]]; then
      if [ "${tester}" "/usr/local/bin/libtool" ]; then
        echo " - ${name} ${COLOR_GREEN}ok${COLOR_NC}"
        continue
      fi
    fi
    DEPS=$DEPS"${name} "
    echo " - ${name} ${COLOR_RED}NOT${COLOR_NC} found!"
    ((COUNT += 1))
  done <$DEPS_FILE
  if [[ $COUNT > 0 ]]; then
    echo ""
    while true; do
      [[ $NONINTERACTIVE == false ]] && printf "${COLOR_YELLOW}Do you wish to install missing dependencies? (y/n)${COLOR_NC}" && read -p " " PROCEED
      echo ""
      case $PROCEED in
      "") echo "What would you like to do?" ;;
      0 | true | [Yy]*)
        "${XCODESELECT}" --install 2>/dev/null || true
        while true; do
          [[ $NONINTERACTIVE == false ]] && printf "${COLOR_YELLOW}Do you wish to update HomeBrew packages first? (y/n)${COLOR_NC}" && read -p " " PROCEED
          case $PROCEED in
          "") echo "What would you like to do?" ;;
          0 | true | [Yy]*)
            echo "${COLOR_CYAN}[Updating HomeBrew]${COLOR_NC}" && brew update
            break
            ;;
          1 | false | [Nn]*)
            echo " - Proceeding without update!"
            break
            ;;
          *) echo "Please type 'y' for yes or 'n' for no." ;;
          esac
        done
        brew tap eosio/eosio
        echo "${COLOR_CYAN}[Installing HomeBrew Dependencies]${COLOR_NC}"
        eval $BREW install $DEPS
        IFS="$OIFS"
        break
        ;;
      1 | false | [Nn]*)
        echo " ${COLOR_RED}- User aborted installation of required dependencies.${COLOR_NC}"
        exit
        ;;
      *) echo "Please type 'y' for yes or 'n' for no." ;;
      esac
    done
  else
    echo "${COLOR_GREEN} - No required package dependencies to install.${COLOR_NC}"
  fi
  echo ""
  echo "FIO READY"
  echo ""
}

([[ ! $NAME == "Ubuntu" ]] && [[ ! $ARCH == "Darwin" ]]) && set -i # Ubuntu doesn't support interactive mode since it uses dash + Some folks are having this issue on Darwin; colors aren't supported yet anyway
echo "${COLOR_CYAN}[Ensuring xcode-select installation]${COLOR_NC}"
if ! XCODESELECT=$(command -v xcode-select); then
  echo " - xcode-select must be installed in order to proceed!" && exit 1
else echo " - xcode-select installation found @ ${XCODESELECT}"; fi

ensure-sudo

if [ "$ARCH" == "Darwin" ]; then
  export OS_VER=$(sw_vers -productVersion)
  export OS_MIN=$(echo "${OS_VER}" | cut -d'.' -f2)
  [[ "${OS_MIN}" -lt 12 ]] && echo "You must be running Mac OS 10.12.x or higher to install FIO." && exit 1

  ensure-homebrew

  if [ ! -d /usr/local/Frameworks ]; then
    echo "${COLOR_YELLOW}/usr/local/Frameworks is necessary to brew install python@3. Run the following commands as sudo and try again:${COLOR_NC}"
    echo "sudo mkdir /usr/local/Frameworks && sudo chown $(whoami):admin /usr/local/Frameworks"
    exit 1
  fi

  ensure-brew-packages "${CURRENT_WORKING_DIR}/build/build_darwin_deps"
fi

if [[ $ARCH == "Linux" ]]; then
  case $NAME in
  "Ubuntu")
    #HERE WE GO
    ;;
  esac
fi
