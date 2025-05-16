#!/bin/bash
export DEBIAN_FRONTEND="noninteractive"
WORKDIR=$HOME/aztec-node
sudo apt-get update -qy > /dev/null 2>&1
sudo apt-get install -y -qq curl ca-certificates sudo > /dev/null 2>&1
source <(curl -s https://raw.githubusercontent.com/CryptoNodeID/helper-script/master/common.sh)
base_colors
header_info
color
catch_errors

REWARD_ADDRESS=""
PRIVATE_KEY=""
RPC_URL=""
BEACON_URL=""
SERVER_IP=$(curl -s https://api.ipify.org)

# Check if the shell is using bash
shell_check

docker_check(){
# Check and install docker if not available
if ! command -v docker &> /dev/null; then
  msg_info "Installing docker..."
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -qy $pkg > /dev/null 2>&1; done
  sudo apt-get update -qy > /dev/null 2>&1
  sudo apt-get -qy install curl > /dev/null 2>&1
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1
  sudo apt-get update -qy > /dev/null 2>&1
  sudo apt-get install -qy docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
  sudo systemctl enable --now docker
  sudo usermod -aG docker $USER
fi
msg_ok "Docker has been installed."
}
install_Sequencer() {
docker_check

if [ -d "$HOME/.aztec" ]; then
  msg_ok "Delete previous aztec config folder"
  rm -rf $HOME/.aztec
fi
bash -i <(curl -s https://install.aztec.network)
msg_ok "Aztec CLI has been installed."
mkdir -p $WORKDIR
cd $WORKDIR
if ! docker network inspect cnid >/dev/null 2>&1; then
  docker network create cnid
fi
tee .env > /dev/null << EOF
UID=$(id -u)
GID=$(id -g)
ETHEREUM_HOSTS="$RPC_URL"
L1_CONSENSUS_HOST_URLS="$BEACON_URL"  
VALIDATOR_PRIVATE_KEY="$PRIVATE_KEY"
COINBASE="$REWARD_ADDRESS"
P2P_IP="$SERVER_IP"
EOF
tee docker-compose.yml > /dev/null << EOF
name: aztec-sequencer
services:
  aztec-sequencer:
    container_name: aztec-sequencer
    restart: unless-stopped
    image: aztecprotocol/aztec:alpha-testnet
    env_file:
      - .env
    user: "\${UID}:\${GID}"
    environment:
      DATA_DIRECTORY: /data
      LOG_LEVEL: debug
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet start --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - ./data:/data
    networks:
      - cnid

networks:
  cnid:
    external: true
EOF
msg_ok "Aztec-Sequencer has been installed."

if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-Sequencer" --yesno "Do you want to run the Aztec-Sequencer?" 10 60); then
    if [ "$(docker ps -q -f name=aztec-sequencer --no-trunc | wc -l)" -ne "0" ]; then
        msg_error "Aztec-Sequencer is already running."
        msg_info "Stopping Aztec-Sequencer..."
        sudo docker kill aztec-sequencer >/dev/null 2>&1
        msg_ok "Aztec-Sequencer has been stopped."
    fi
    msg_ok "Aztec-Sequencer check complete."
    msg_info "Starting Aztec-Sequencer..."
    sudo docker compose -f $WORKDIR/docker-compose.yml up -d >/dev/null 2>&1
    msg_ok "Aztec-Sequencer started successfully.\n"
fi
echo -e "${INFO}${GN} To start Aztec-Sequencer, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml up -d'${CL}"
echo -e "${INFO}${GN} To stop Aztec-Sequencer, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml down'${CL}"
echo -e "${INFO}${GN} To restart Aztec-Sequencer, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml restart'${CL}"
echo -e "${INFO}${GN} To check the logs of Aztec-Sequencer, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml logs -fn 100'${CL}"
}

init_aztec() {
if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --yesno "This script will install the Aztec-${1}. Do you want to continue?" 10 60); then
    while [ -z "$REWARD_ADDRESS" ]; do
      if REWARD_ADDRESS=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --inputbox "Input your reward address (EVM starting with 0x):" 8 60 3>&1 1>&2 2>&3); then
        if [[ $REWARD_ADDRESS != 0x* ]]; then
            whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --msgbox "Error: Reward Address must start with 0x" 8 60
            REWARD_ADDRESS=""
        else
            break
        fi
      else
        exit_script
      fi
    done
    while [ -z "$PRIVATE_KEY" ]; do
      if PRIVATE_KEY=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --inputbox "Input your private key (EVM starting with 0x):" 8 60 3>&1 1>&2 2>&3); then
        if [[ $PRIVATE_KEY != 0x* ]]; then
            whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --msgbox "Error: Private Key must start with 0x" 8 60
            PRIVATE_KEY=""
        else
            break
        fi
      else
        exit_script
      fi
    done
    while [ -z "$RPC_URL" ]; do
      if RPC_URL=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --inputbox "Input your Ethereum RPC URL:" 8 60 3>&1 1>&2 2>&3); then
        if [[ $RPC_URL != http* ]]; then
            whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --msgbox "Error: Ethereum RPC URL must start with http" 8 60
            RPC_URL=""
        else
            break
        fi
      else
        exit_script
      fi
    done
    while [ -z "$BEACON_URL" ]; do
      if BEACON_URL=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --inputbox "Input your Ethereum Beacon RPC URL:" 8 60 3>&1 1>&2 2>&3); then
        if [[ $BEACON_URL != http* ]]; then
            whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --msgbox "Error: Ethereum Beacon RPC URL must start with http" 8 60
            BEACON_URL=""
        else
            break
        fi
      else
        exit_script
      fi
    done
    if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-${1}" --yesno \
        "Summary of the input:\n\nReward Address: $REWARD_ADDRESS\nPrivate Key: $PRIVATE_KEY\nEthereum RPC URL: $RPC_URL\nEthereum Beacon RPC URL: $BEACON_URL\n\nPlease confirm the input above. If not, the script will start from the beginning." 15 60); then
        install_${1}
    else
        REWARD_ADDRESS=""
        PRIVATE_KEY=""
        RPC_URL=""
        BEACON_URL=""
        init_aztec "${1}"
    fi
else
    exit_script
fi
}

while true; do
    choice=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Aztec-Node" --menu "Choose the type of Aztec-Node to install:" 10 70 4 \
        "Sequencer" "     Install the Aztec-Sequencer (Default)" \
        "Exit" "     Exit the script"  --nocancel --default-item "Sequencer" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
      echo -e "${CROSS}${RD} Menu canceled. Exiting.${CL}"
      exit 0
    fi

    case $choice in
        "Sequencer")
          init_aztec "Sequencer"
          break
          ;;
        "Exit")
          exit_script
          ;;
        *)
          echo -e "${CROSS}${RD}Invalid option, please try again.${CL}"
          ;;
    esac
done
