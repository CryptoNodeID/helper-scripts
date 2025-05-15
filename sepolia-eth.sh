#!/bin/bash
export DEBIAN_FRONTEND="noninteractive"
WORKDIR=$HOME/sepolia-eth
sudo apt-get update -qy > /dev/null 2>&1
sudo apt-get install -y -qq curl ca-certificates sudo > /dev/null 2>&1
source <(curl -s https://raw.githubusercontent.com/CryptoNodeID/helper-script/master/common.sh)
base_colors
header_info
color
catch_errors

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
install_ETH() {
docker_check

if ! docker network inspect cnid >/dev/null 2>&1; then
  docker network create cnid
fi
mkdir -p $WORKDIR/geth-data
mkdir -p $WORKDIR/prysm-data
mkdir -p $WORKDIR/jwt
cd $WORKDIR
echo "UID=$(id -u)" >> .env
echo "GID=$(id -g)" >> .env
tee docker-compose.yml > /dev/null << EOF
services:
  geth-sepolia:
    container_name: geth-sepolia
    env_file: .env
    user: "\${UID}:\${GID}"
    image: ethereum/client-go:stable
    restart: unless-stopped
    command:
      --sepolia
      --authrpc.port=22551
      --ws
      --ws.addr=0.0.0.0
      --ws.origins="*"
      --ws.port=22546
      --datadir=/data
      --http
      --http.addr=0.0.0.0
      --http.api="eth,net,engine,admin,txpool"
      --http.corsdomain="*"
      --http.vhosts="*"
      --http.port=22545
      --ipcdisable
      --authrpc.addr=0.0.0.0
      --authrpc.vhosts="*"
      --authrpc.jwtsecret=/jwt/jwtsecret
      --syncmode full
      --cache 4096
      --metrics
      --metrics.addr=0.0.0.0
      --metrics.port=22660
      --discovery.port=22303
    volumes:
      - './geth-data:/data'
      - './jwt:/jwt'
    ports:
      - '22303:22303'
      - '22545:22545' #json-rpc endpoint
      - '22546:22546' #wss endpoint
      - '22547:22547'
      - '22551:22551' #auth endpoint
      - '22660:22660' #metric
    networks:
      - cnid
  prysm-sepolia:
    container_name: prysm-sepolia
    env_file: .env
    user: "\${UID}:\${GID}"
    image: gcr.io/prysmaticlabs/prysm/beacon-chain:stable
    restart: unless-stopped
    command: --datadir=/data
      --jwt-secret=/jwt/jwtsecret
      --rpc-host=0.0.0.0
      --grpc-gateway-host=0.0.0.0
      --monitoring-host=0.0.0.0
      --execution-endpoint=http://geth-sepolia:22551
      --genesis-beacon-api-url=https://sepolia.beaconstate.info
      --checkpoint-sync-url=https://sepolia.beaconstate.info
      --enable-experimental-backfill=true
      --sepolia --accept-terms-of-use
      --p2p-tcp-port=22300
      --p2p-udp-port=22200
      --grpc-gateway-port=22500
    volumes:
      - "./prysm-data:/data"
      - "./jwt:/jwt"
    ports:
      - '22400:22400'
      - '22500:22500' #beacon endpoint
      - '22300:22300'
      - '22200:22200/udp'
    networks:
      - cnid

networks:
  cnid:
    external: true
EOF
msg_ok "Sepolia-ETH has been installed."

if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Sepolia-ETH" --yesno "Do you want to run the Sepolia-ETH?" 10 60); then
    if [ "$(docker ps -q -f name=geth-sepolia --no-trunc | wc -l)" -ne "0" ]; then
        msg_error "Sepolia-ETH is already running."
        msg_info "Stopping Sepolia-ETH..."
        sudo docker kill geth-sepolia prysm-sepolia >/dev/null 2>&1
        msg_ok "Sepolia-ETH has been stopped."
    fi
    msg_ok "Sepolia-ETH check complete."
    msg_info "Starting Sepolia-ETH..."
    sudo docker compose -f $WORKDIR/docker-compose.yml up -d >/dev/null 2>&1
    msg_ok "Sepolia-ETH started successfully.\n"
fi
echo -e "${INFO}${GN} To start Sepolia-ETH, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml up -d'${CL}"
echo -e "${INFO}${GN} To stop Sepolia-ETH, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml down'${CL}"
echo -e "${INFO}${GN} To restart Sepolia-ETH, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml restart'${CL}"
echo -e "${INFO}${GN} To check the logs of Sepolia-ETH, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml logs -fn 100'${CL}"
}

init_sepoliaeth() {
if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Sepolia-${1}" --yesno "This script will install the Sepolia-${1}. Do you want to continue?" 10 60); then
    install_${1}
else
    exit_script
fi
}

while true; do
    choice=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Sepolia-ETH" --menu "Choose the type of Sepolia-ETH to install:" 10 70 4 \
        "SepoliaEth" "     Install the Sepolia-ETH (Default)" \
        "Exit" "     Exit the script"  --nocancel --default-item "SepoliaEth" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
      echo -e "${CROSS}${RD} Menu canceled. Exiting.${CL}"
      exit 0
    fi

    case $choice in
        "SepoliaEth")
          init_sepoliaeth "ETH"
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
