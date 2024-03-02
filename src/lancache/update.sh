#!/bin/bash -ex
# shellcheck disable=SC2034

webroot="/var/www/html"
webInterfaceGitUrl="https://github.com/DjoSmer/pi-hole-web.git"
webInterfaceGitBranch="lancache"
webInterfaceDir="${webroot}/admin"
piholeGitUrl="https://github.com/DjoSmer/pi-hole.git"
piholeGitBranch="custom_wildcard_dns"
PI_HOLE_LOCAL_REPO="/etc/.pihole"
PI_HOLE_FILES=(chronometer list piholeDebug piholeLogFlush setupLCD update version gravity uninstall webpage)
PI_HOLE_INSTALL_DIR="/opt/pihole"

INSTALL_WEB_INTERFACE=true
INSTALL_WEB_SERVER=true
# The Web server user,
LIGHTTPD_USER="www-data"
# group,
LIGHTTPD_GROUP="www-data"
# and config file

if [ -z "${USER}" ]; then
  USER="$(id -un)"
fi

# Set these values so the installer can still run in color
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_LIGHT_RED='\e[1;31m'
TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="[${COL_LIGHT_RED}✗${COL_NC}]"
INFO="[i]"
# shellcheck disable=SC2034
DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
OVER="\\r\\033[K"

# A function to clone a repo
make_repo() {
  # Set named variables for better readability
  local directory="${1}"
  local remoteRepo="${2}"
  local remoteBranch="${3}"
  local branch=""

  if [[ -n "${remoteBranch}" ]]; then
    branch="-b ${remoteBranch}"
  fi

  # The message to display when this function is running
  str="Clone ${remoteRepo} into ${directory}"
  # Display the message and use the color table to preface the message with an "info" indicator
  printf "  %b %s..." "${INFO}" "${str}"
  # If the directory exists,
  if [[ -d "${directory}" ]]; then
    # Return with a 1 to exit the installer. We don't want to overwrite what could already be here in case it is not ours
    str="Unable to clone ${remoteRepo} into ${directory} : Directory already exists"
    printf "%b  %b%s\\n" "${OVER}" "${CROSS}" "${str}"
    return 1
  fi
  # Clone the repo and return the return code from this command
  git clone -q --depth 20 "${remoteRepo}" ${branch} "${directory}" &>/dev/null || return $?
  # Move into the directory that was passed as an argument
  pushd "${directory}" &>/dev/null || return 1
  # Check current branch. If it is master, then reset to the latest available tag.
  # In case extra commits have been added after tagging/release (i.e in case of metadata updates/README.MD tweaks)
  curBranch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "${curBranch}" == "master" ]]; then
    # If we're calling make_repo() then it should always be master, we may not need to check.
    git reset --hard "$(git describe --abbrev=0 --tags)" || return $?
  fi
  # Show a colored message showing it's status
  printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
  # Data in the repositories is public anyway so we can make it readable by everyone (+r to keep executable permission if already set by git)
  chmod -R a+rX "${directory}"
  # Move back into the original directory
  popd &>/dev/null || return 1
  return 0
}

# Clean an existing installation to prepare for upgrade/reinstall
clean_existing() {
  # Local, named variables
  # ${1} Directory to clean
  local clean_directory="${1}"
  # Pop the first argument, and shift all addresses down by one (i.e. ${2} becomes ${1})
  shift
  # Then, we can access all arguments ($@) without including the directory to clean
  local old_files=("$@")

  # Remove each script in the old_files array
  for script in "${old_files[@]}"; do
    rm -f "${clean_directory}/${script}.sh"
  done
}

# A function for checking if a directory is a git repository
is_repo() {
  # Use a named, local variable instead of the vague $1, which is the first argument passed to this function
  # These local variables should always be lowercase
  local directory="${1}"
  # A variable to store the return code
  local rc
  # If the first argument passed to this function is a directory,
  if [[ -d "${directory}" ]]; then
    # move into the directory
    pushd "${directory}" &>/dev/null || return 1
    # Use git to check if the directory is a repo
    # git -C is not used here to support git versions older than 1.8.4
    git status --short &>/dev/null || rc=$?
  # If the command was not successful,
  else
    # Set a non-zero return code if directory does not exist
    rc=1
  fi
  # Move back into the directory the user started in
  popd &>/dev/null || return 1
  # Return the code; if one is not set, return 0
  return "${rc:-0}"
}

# Install the scripts from repository to their various locations
installScripts() {
  # Local, named variables
  local str="Installing scripts from ${PI_HOLE_LOCAL_REPO}"
  printf "  %b %s..." "${INFO}" "${str}"

  # Clear out script files from Pi-hole scripts directory.
  clean_existing "${PI_HOLE_INSTALL_DIR}" "${PI_HOLE_FILES[@]}"

  # Install files from local core repository
  if is_repo "${PI_HOLE_LOCAL_REPO}"; then
    # move into the directory
    cd "${PI_HOLE_LOCAL_REPO}"
    # Install the scripts by:
    #  -o setting the owner to the user
    #  -Dm755 create all leading components of destination except the last, then copy the source to the destination and setting the permissions to 755
    #
    # This first one is the directory
    install -o "${USER}" -Dm755 -d "${PI_HOLE_INSTALL_DIR}"
    # The rest are the scripts Pi-hole needs
    install -o "${USER}" -Dm755 -t "${PI_HOLE_INSTALL_DIR}" gravity.sh
    install -o "${USER}" -Dm755 -t "${PI_HOLE_INSTALL_DIR}" ./advanced/Scripts/*.sh
    install -o "${USER}" -Dm755 -t "${PI_HOLE_INSTALL_DIR}" ./automated\ install/uninstall.sh
    install -o "${USER}" -Dm755 -t "${PI_HOLE_INSTALL_DIR}" ./advanced/Scripts/COL_TABLE
    install -o "${USER}" -Dm755 -t "${PI_HOLE_BIN_DIR}" pihole
    install -Dm644 ./advanced/bash-completion/pihole /etc/bash_completion.d/pihole
    printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"

  else
    # Otherwise, show an error and exit
    printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
    printf "\\t\\t%bError: Local repo %s not found, exiting installer%b\\n" "${COL_LIGHT_RED}" "${PI_HOLE_LOCAL_REPO}" "${COL_NC}"
    return 1
  fi
}

# Install base files and web interface
installPihole() {
  # If the user wants to install the Web interface,
  if [[ "${INSTALL_WEB_INTERFACE}" == true ]]; then
    if [[ ! -d "${webroot}" ]]; then
      # make the Web directory if necessary
      install -d -m 0755 ${webroot}
    fi

    if [[ "${INSTALL_WEB_SERVER}" == true ]]; then
      # Set the owner and permissions
      chown ${LIGHTTPD_USER}:${LIGHTTPD_GROUP} ${webroot}
      chmod 0775 ${webroot}
      # Repair permissions if webroot is not world readable
      chmod a+rx /var/www
      chmod a+rx ${webroot}
      # Give lighttpd access to the pihole group so the web interface can
      # manage the gravity.db database
      usermod -a -G pihole ${LIGHTTPD_USER}
    fi
  fi
  # Install base files and web interface
  if ! installScripts; then
    printf "  %b Failure in dependent script copy function.\\n" "${CROSS}"
    exit 1
  fi

  # /opt/pihole/utils.sh should be installed by installScripts now, so we can use it
  if [ -f "${PI_HOLE_INSTALL_DIR}/utils.sh" ]; then
    # shellcheck disable=SC1091
    source "${PI_HOLE_INSTALL_DIR}/utils.sh"
  else
    printf "  %b Failure: /opt/pihole/utils.sh does not exist .\\n" "${CROSS}"
    exit 1
  fi
}

rm -rf $PI_HOLE_LOCAL_REPO 2>/dev/null
make_repo "${PI_HOLE_LOCAL_REPO}" "${piholeGitUrl}" "${piholeGitBranch}"

rm -rf $webInterfaceDir
make_repo "${webInterfaceDir}" "${webInterfaceGitUrl}" "$webInterfaceGitBranch"

installPihole
