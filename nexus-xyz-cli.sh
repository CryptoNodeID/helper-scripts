#!/bin/bash
export DEBIAN_FRONTEND="noninteractive"
WORKDIR=$HOME/nexus-xyz-cli
sudo apt-get update -qy > /dev/null 2>&1
sudo apt-get install -y -qq curl ca-certificates sudo > /dev/null 2>&1
source <(curl -s https://raw.githubusercontent.com/CryptoNodeID/helper-script/master/common.sh)
base_colors
header_info
color
catch_errors

NODE_ID=""

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
install_Node() {
docker_check

mkdir -p $WORKDIR
cd $WORKDIR

tee Dockerfile > /dev/null << EOF
FROM rust:latest AS builder

RUN apt update && \\
    apt install -y build-essential pkg-config libssl-dev protobuf-compiler && \\
    mkdir /root/.nexus && \\
    cd /root/.nexus && \\
    git clone https://github.com/nexus-xyz/network-api && \\
    cd network-api && \\
    git -c advice.detachedHead=false checkout \$(git rev-list --tags --max-count=1)

WORKDIR /root/.nexus/network-api/clients/cli

RUN cargo build --release --bin nexus-network

FROM ubuntu:noble

RUN apt update && \\
    apt install -y ca-certificates pkg-config libssl-dev && \\
    mkdir /root/.nexus

COPY --from=builder /root/.nexus/network-api/clients/cli/src /root/.nexus/src
COPY --from=builder /root/.nexus/network-api/clients/cli/target/release/nexus-network /root/.nexus/nexus-network

WORKDIR /root/.nexus

COPY entrypoint.sh .

RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
EOF
tee docker-compose.yml > /dev/null << EOF
services:
  nexus-xyz-cli:
    container_name: nexus-xyz-cli
    image: nexus-xyz-cli:latest
    restart: unless-stopped
    stop_grace_period: 5m
    environment:
      - NODE_ID=${NODE_ID}
EOF
tee entrypoint.sh > /dev/null << EOF
#!/bin/sh

if [ -z "\${NODE_ID}" ]; then
    echo "Error: NODE_ID environment variable is not set or is empty"
    exit 1
fi

NEXUS_HOME=\$HOME/.nexus
echo "\$NODE_ID" > \$NEXUS_HOME/node-id
cd \$NEXUS_HOME
echo "y" | ./nexus-network --start --beta

exec "\$@"
EOF
msg_info "Building Nexus-xyz-CLI..."
sudo docker build -t nexus-xyz-cli:latest -f Dockerfile . >/dev/null 2>&1
msg_ok "Nexus-xyz-CLI has been built."
rm -rf Dockerfile entrypoint.sh
msg_ok "Nexus-xyz-CLI has been installed."

if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Nexus-xyz-CLI" --yesno "Do you want to run the Nexus-xyz-CLI?" 10 60); then
    if [ "$(docker ps -q -f name=nexus-xyz-cli --no-trunc | wc -l)" -ne "0" ]; then
        msg_error "Nexus-xyz-CLI is already running."
        msg_info "Stopping Nexus-xyz-CLI..."
        sudo docker kill nexus-xyz-cli >/dev/null 2>&1
        msg_ok "Nexus-xyz-CLI has been stopped."
    fi
    if [ "$(docker images -q nexus-xyz-cli-nexus-xyz-cli 2> /dev/null)" != "" ]; then
        msg_error "Old Nexus-xyz-CLI found."
        msg_info "Removing old Nexus-xyz-CLI..."
        sudo docker rmi nexus-xyz-cli-nexus-xyz-cli -f >/dev/null 2>&1
        msg_ok "Old Nexus-xyz-CLI has been removed."        
    fi
    msg_ok "Nexus-xyz-CLI check complete."
    msg_info "Starting Nexus-xyz-CLI..."
    sudo docker compose -f $WORKDIR/docker-compose.yml up -d >/dev/null 2>&1
    msg_ok "Nexus-xyz-CLI started successfully.\n"
fi
echo -e "${INFO}${GN} To start Nexus-xyz-CLI, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml up -d'${CL}"
echo -e "${INFO}${GN} To stop Nexus-xyz-CLI, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml down'${CL}"
echo -e "${INFO}${GN} To restart Nexus-xyz-CLI, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml restart'${CL}"
echo -e "${INFO}${GN} To check the logs of Nexus-xyz-CLI, run the command: 'sudo docker compose -f $WORKDIR/docker-compose.yml logs -fn 100'${CL}"
}

install_Add-Node() {
if [ "$(docker images -q nexus-xyz-cli:latest 2> /dev/null)" = "" ]; then
    msg_error "Nexus-xyz-CLI image not found."
    init_nexus "Node"
else
    msg_ok "Nexus-xyz-CLI image found."
fi
NODE_ID=$(cat ~/.nexus/node-id)
NODE_Num=""
while true; do
  if NODE_Num=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Nexus-xyz-CLI Add" --inputbox "How many nodes would you like to have:" 8 60 3>&1 1>&2 2>&3); then
    if [[ $NODE_Num =~ ^[1-9][0-9]*$ ]] && [ $NODE_Num -gt 1 ] && [ -n "$NODE_Num" ]; then
      i=$(find $WORKDIR/ -name "docker-compose*" | wc -l)
      while [ $i -le $NODE_Num ]; do
      i=$((i+1))
      msg_info "Creating docker-compose${i}.yml..."
      tee $WORKDIR/docker-compose${i}.yml > /dev/null <<EOF
services:
  nexus-xyz-cli-${i}:
    container_name: nexus-xyz-cli-${i}
    image: nexus-xyz-cli:latest
    restart: unless-stopped
    environment:
      - NODE_ID=${NODE_ID}
    stop_grace_period: 5m
EOF
      msg_ok "docker-compose${i}.yml created successfully."
      done
      break
    else
      whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier Add" --msgbox "Error: Number must be greater than 1" 8 60
      NODE_Num=""
    fi
  else
    exit_script
  fi
done
echo -e "${INFO}${GN} To start all Nexus-xyz-CLI, run the command: 'for i in \$(ls -d -1 $WORKDIR/* | grep -e "docker-compose"); do sudo docker compose -f \$i up -d; done'${CL}"
echo -e "${INFO}${GN} To stop all Nexus-xyz-CLI, run the command: 'for i in \$(ls -d -1 $WORKDIR/* | grep -e "docker-compose"); do sudo docker compose -f \$i down; done'${CL}"
}

init_nexus() {
if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Nexus-${1}" --yesno "This script will install the Nexus-${1}. Do you want to continue?" 10 60); then
    while [ -z "$NODE_ID" ]; do
      if NODE_ID=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Nexus-${1}" --inputbox "Input your Node-ID:" 8 60 3>&1 1>&2 2>&3); then
        if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Nexus-${1}" --yesno "\nNode-ID: $NODE_ID\n\nContinue with the installation?" 10 60); then
            break
        else
            NODE_ID=""
        fi
      else
        exit_script
      fi
    done
    install_${1}
else
    exit_script
fi
}

while true; do
    choice=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Nexus-Node" --menu "Choose the type of Nexus-Node to install:" 10 70 4 \
        "Install" "     Install the Nexus-xyz-CLI (Default)" \
        "Add Node" "     Need to install Nexus-xyz-CLI first" \
        "Exit" "     Exit the script"  --nocancel --default-item "Install" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
      echo -e "${CROSS}${RD} Menu canceled. Exiting.${CL}"
      exit 0
    fi

    case $choice in
        "Install")
          init_nexus "Node"
          break
          ;;
        "Add Node")
          install_Add-Node
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
