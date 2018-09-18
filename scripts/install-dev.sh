#! /bin/bash

# Set "echo -e" as default
shopt -s xpg_echo

RED="\033[0;91m"
GREEN="\033[0;92m"
YELLOW="\033[0;93m"
BLUE="\033[0;94m"
CYAN="\033[0;96m"
WHITE="\033[0;97m"
LRED="\033[1;31m"
LGREEN="\033[1;32m"
LYELLOW="\033[1;33m"
LBLUE="\033[1;34m"
LCYAN="\033[1;36m"
LWHITE="\033[1;37m"
LG="\033[0;37m"
NC="\033[0m"

readlinkf() {
  python -c "import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))" "${1}"
}

usage() {
  echo "${GREEN}Backend.AI Development Setup${NC}: ${CYAN}Auto-installer Tool${NC}"
  echo ""
  echo "Usage: $0 ${BLUE}[OPTIONS]${NC}"
  echo ""
  echo "${BLUE}OPTIONS:${NC}"
  echo "  ${LWHITE}-h, --help${NC}           Show this help message and exit"
  echo "  ${LWHITE}--python-version VERSION${NC}"
  echo "                       Set the Python version to install via pyenv"
  echo "                       (default: 3.6.6)"
  echo "  ${LWHITE}--install-path PATH${NC}  Set the target directory"
  echo "                       (default: ./backend.ai-dev)"
  echo "  ${LWHITE}--server-branch NAME${NC}"
  echo "                       The branch of git clones for server components"
  echo "                       (default: master)"
  echo "  ${LWHITE}--client-branch NAME${NC}"
  echo "                       The branch of git clones for client components"
  echo "                       (default: master)"
  echo "  ${LWHITE}--enable-cuda${NC}        Install CUDA accelerator plugin (default: false)"
}

ROOT_PATH=$(pwd)
PYTHON_VERSION="3.6.6"
SERVER_BRANCH="master"
CLIENT_BRANCH="master"
INSTALL_PATH="./backend.ai-dev"
ENABLE_GPU=0

while [ $# -gt 0 ]; do
  case $1 in
    -h | --help)        usage; exit 1 ;;
    --python-version)   PYTHON_VERSION=$2; shift ;;
    --python-version=*) PYTHON_VERSION="${1#*=}" ;;
    --install-path)     INSTALL_PATH=$2; shift ;;
    --install-path=*)   INSTALL_PATH="${1#*=}" ;;
    --server-branch)    SERVER_BRANCH=$2; shift ;;
    --server-branch=*)  SERVER_BRANCH="${1#*=}" ;;
    --client-branch)    CLIENT_BRANCH=$2; shift ;;
    --client-branch=*)  CLIENT_BRANCH="${1#*=}" ;;
    --enable-cuda)      ENABLE_CUDA=1 ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage."
      exit 1
  esac
  shift
done
INSTALL_PATH=$(readlinkf "$INSTALL_PATH")

show_error() {
  echo " "
  echo "${RED}[ERROR]${NC} ${LRED}$1${NC}"
}

show_info() {
  echo " "
  echo "${BLUE}[INFO]${NC} ${GREEN}$1${NC}"
}

show_note() {
  echo " "
  echo "${BLUE}[NOTE]${NC} $1"
}

show_important_note() {
  echo " "
  echo "${LRED}[NOTE]${NC} $1"
}

# TODO: check if CUDA runtime is available?


# BEGIN!

echo " "
echo "${LGREEN}Backend.AI one-line installer for developers${NC}"

# NOTE: docker-compose enforces lower-cased project names
ENV_ID=$(LC_CTYPE=C tr -dc 'a-z0-9' < /dev/urandom | head -c 8)

# Check prerequistics
if ! type "docker" > /dev/null; then
  show_error "docker is not available!"
  show_info "Install the latest version of docker and try again."
  exit 1
fi
if ! type "docker-compose" > /dev/null; then
  show_error "docker-compose is not available!"
  show_info "Install the latest version of docker-compose and try again."
  exit 1
fi

# Make directories
show_info "Creating backend.ai-dev directory..."
mkdir -p "${INSTALL_PATH}"
cd "${INSTALL_PATH}"

# Install postgresql, etcd packages via docker
git clone --branch "${SERVER_BRANCH}" https://github.com/lablup/backend.ai
cd backend.ai
docker-compose -f docker-compose.halfstack.yml -p "${ENV_ID}" up -d
docker ps | grep "${ENV_ID}"   # You should see three containers here.

# install pyenv
if ! type "pyenv" > /dev/null; then
  # TODO: ask if install pyenv
  show_info "Installing pyenv..."
  git clone https://github.com/pyenv/pyenv.git "${HOME}/.pyenv"
  git clone https://github.com/pyenv/pyenv-virtualenv.git "${HOME}/.pyenv/plugins/pyenv-virtualenv"
  for PROFILE_FILE in "zshrc" "bashrc" "profile" "bash_profile"
  do
    if [ -e "${HOME}/.${PROFILE_FILE}" ]
    then
      echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "${HOME}/.${PROFILE_FILE}"
      echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "${HOME}/.${PROFILE_FILE}"
      echo 'eval "$(pyenv init -)"' >> "${HOME}/.${PROFILE_FILE}"
      echo 'eval "$(pyenv virtualenv-init -)"' >> ""${HOME}/.${PROFILE_FILE}
      exec "$SHELL" -l
    fi
  done
  pyenv
fi

# Install python to pyenv environment
show_info "Creating virtualenv on pyenv..."
pyenv install -s "${PYTHON_VERSION}"
pyenv virtualenv "${PYTHON_VERSION}" "venv-${ENV_ID}-manager"
pyenv virtualenv "${PYTHON_VERSION}" "venv-${ENV_ID}-agent"
pyenv virtualenv "${PYTHON_VERSION}" "venv-${ENV_ID}-common"
pyenv virtualenv "${PYTHON_VERSION}" "venv-${ENV_ID}-client"

# Clone source codes
show_info "Cloning backend.ai source codes..."
cd "${INSTALL_PATH}"
git clone --branch "${SERVER_BRANCH}" https://github.com/lablup/backend.ai-manager manager
git clone --branch "${SERVER_BRANCH}" https://github.com/lablup/backend.ai-agent agent
git clone --branch "${SERVER_BRANCH}" https://github.com/lablup/backend.ai-common common

# Setup virtual environments
cd "${INSTALL_PATH}/manager"
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    if [ $(python -c "from ctypes.util import find_library;print(find_library('snappy'))") = "None" ]; then
        show_error "You need snappy library to install backend.ai components."
        show_info "Install libsnappy-dev (Debian-likes), or libsnappy-devel (RHEL-likes) system package depending on your environment."
        exit 1
    fi
    # NOTE: python-snappy 0.5.3 or later supports binary wheels on macOS.
fi

show_info "Install packages on virtual environments..."
cd "${INSTALL_PATH}/manager"
pyenv local "venv-${ENV_ID}-manager"
pip install -U -q pip setuptools
pip install -U -e ../common -r requirements-dev.txt

cd "${INSTALL_PATH}/agent"
pyenv local "venv-${ENV_ID}-agent"
pip install -U -q pip setuptools
pip install -U -e ../common -r requirements-dev.txt
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  sudo setcap cap_sys_ptrace,cap_sys_admin,cap_dac_override+eip $(readlinkf $(pyenv which python))
fi

cd "${INSTALL_PATH}/common"
pyenv local "venv-${ENV_ID}-common"
pip install -U -q pip setuptools
pip install -U -r requirements-dev.txt

# Manager DB setup
show_info "Configuring kernel images..."
cd "${INSTALL_PATH}/manager"
cp sample-configs/image-metadata.yml image-metadata.yml
cp sample-configs/image-aliases.yml image-aliases.yml
./scripts/run-with-halfstack.sh python -m ai.backend.manager.cli etcd update-images -f image-metadata.yml
./scripts/run-with-halfstack.sh python -m ai.backend.manager.cli etcd update-aliases -f image-aliases.yml

# Virtual folder setup
show_info "Setting up virtual folder..."
mkdir -p "${INSTALL_PATH}/vfolder/azure-shard01"  # TODO: fix
./scripts/run-with-halfstack.sh python -m ai.backend.manager.cli etcd put volumes/_vfroot "${INSTALL_PATH}/vfolder"
cd "${INSTALL_PATH}/agent"
mkdir -p scratches

# DB schema
show_info "Setting up databases..."
cd "${INSTALL_PATH}/manager"
cp alembic.ini.sample alembic.ini
python -m ai.backend.manager.cli schema oneshot head
python -m ai.backend.manager.cli --db-addr=localhost:8100 --db-user=postgres --db-password=develove --db-name=backend fixture populate example_keypair

show_info "Installing Python client SDK/CLI source..."
cd "${INSTALL_PATH}"
# Install python client package
git clone --branch "${CLIENT_BRANCH}" https://github.com/lablup/backend.ai-client-py client-py
cd "${INSTALL_PATH}/client-py"
pyenv local "venv-${ENV_ID}-client"
pip install -U -q pip setuptools
pip install -U -r requirements-dev.txt

show_info "Downloading Python kernel images for Backend.AI..."
docker pull lablup/kernel-python:3.6-debian
docker pull lablup/kernel-python-tensorflow:1.7-py36

cd "${INSTALL_PATH}"
show_info "Installation finished."
show_note "Default API keypair configuration for test / develop:"
echo "> ${WHITE}export BACKEND_ENDPOINT=http://127.0.0.1:8081/${NC}"
echo "> ${WHITE}export BACKEND_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE${NC}"
echo "> ${WHITE}export BACKEND_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY${NC}"
echo " "
echo "Please add these environment variables to your shell configuration files."
show_important_note "You should change your default admin API keypairs for production environment!"
show_note "How to run Backend.AI manager:"
echo "> ${WHITE}cd ${INSTALL_PATH}/manager${NC}"
echo "> ${WHITE}./scripts/run-with-halfstack.sh python -m ai.backend.gateway.server --service-port=8081 --debug${NC}"
show_note "How to run Backend.AI agent:"
echo "> ${WHITE}cd ${INSTALL_PATH}/agent${NC}"
echo "> ${WHITE}./scripts/run-with-halfstack.sh python -m ai.backend.agent.server --scratch-root=\$(pwd)/scratches --debug --idle-timeout 30${NC}"
show_note "How to run your first code:"
echo "> ${WHITE}cd ${INSTALL_PATH}/client-py${NC}"
echo "> ${WHITE}backend.ai --help${NC}"
echo "> ${WHITE}backend.ai run python -c \"print('Hello World!')\"${NC}"
echo " "
echo "${GREEN}Development environment is now ready.${NC}"
show_note "Your environment ID is ${YELLOW}${ENV_ID}${NC}."
echo "  * When using docker-compose, do:"
echo "    > ${WHITE}cd ${INSTALL_PATH}/manager${NC}"
echo "    > ${WHITE}docker-compose -p ${ENV_ID} -f docker-compose.halfstack.yml ...${NC}"
echo "  * To delete this development environment, run:"
echo "    > ${WHITE}$(dirname $0)/delete-dev.sh --env ${ENV_ID}${NC}"
echo " "