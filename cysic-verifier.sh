#!/bin/bash
source <(curl -s https://raw.githubusercontent.com/CryptoNodeID/helper-script/master/common.sh)
base_colors
header_info
color
catch_errors

REWARD_ADDRESS=""

# Check if the shell is using bash
shell_check

install() {
# Check and install docker if not available
if ! command -v docker &> /dev/null; then
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -qy $pkg; done
    sudo apt update -qy
    sudo apt -qy install curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update -qy
    sudo apt install -qy docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    msg_ok "Docker has been installed."
fi

mkdir -p $HOME/cysic-verifier
cd $HOME/cysic-verifier

tee Dockerfile > /dev/null << EOF
FROM debian:bullseye-slim

RUN apt update -qq && \
    apt install -y -qq curl ca-certificates libc6 && \
    curl -sL https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_linux.sh -o /root/setup_linux.sh

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
EOF
tee docker-compose.yml > /dev/null << EOF
services:
  cysic-verifier:
    container_name: cysic-verifier
    build: .
    restart: unless-stopped
    volumes:
      - ${PWD}/data/.cysic:/root/.cysic
      - ${PWD}/data/app:/app/data
    environment:
      - REWARD_ADDRESS=${REWARD_ADDRESS}
    stop_grace_period: 5m
    network_mode: host
EOF
tee entrypoint.sh > /dev/null << EOF
#!/bin/sh
if [ -z "\${REWARD_ADDRESS}" ]; then
    echo "Error: REWARD_ADDRESS environment variable is not set or is empty"
    exit 1
fi
bash ./root/setup_linux.sh \${REWARD_ADDRESS}
cd /root/cysic-verifier
bash ./start.sh
EOF
msg_ok "Cysic-Verifier has been installed."
}

if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --yesno "This script will install the Cysic-Verifier. Do you want to continue?" 10 60); then
    while [ -z "$REWARD_ADDRESS" ]; do
      if REWARD_ADDRESS=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --inputbox "Input your reward address (EVM starting with 0x):" 8 60 3>&1 1>&2 2>&3); then
        if [[ $REWARD_ADDRESS != 0x* ]]; then
            whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --msgbox "Error: Reward Address must start with 0x" 8 60
            REWARD_ADDRESS=""
        elif (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --yesno "\nReward Address: $REWARD_ADDRESS\n\nContinue with the installation?" 10 60); then
            break
        else
            REWARD_ADDRESS=""
        fi
      else
        exit_script
      fi
    done
    install
else
    exit_script
fi

if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --yesno "Do you want to run the Cysic-Verifier?" 10 60); then
    if [ "$(docker ps -q -f name=cysic-verifier --no-trunc | wc -l)" -ne "0" ]; then
        msg_error "Cysic-Verifier is already running."
        msg_info "Stopping Cysic-Verifier..."
        sudo docker kill cysic-verifier >/dev/null 2>&1
        msg_ok "Cysic-Verifier has been stopped."
    fi
    if [ "$(docker images -q cysic-verifier-cysic-verifier 2> /dev/null)" != "" ]; then
        msg_error "Old Cysic-Verifier found."
        msg_info "Removing old Cysic-Verifier..."
        sudo docker rmi cysic-verifier-cysic-verifier -f >/dev/null 2>&1
        msg_ok "Old Cysic-Verifier has been removed."        
    fi
    msg_ok "Cysic-Verifier check complete."
    msg_info "Starting Cysic-Verifier..."
    sudo docker compose -f $HOME/cysic-verifier/docker-compose.yml up -d >/dev/null 2>&1
    msg_ok "Cysic-Verifier started successfully.\n"
fi

echo -e "${ROOTSSH}${YW} Please backup your Cysic-Verifier keys folder. '$HOME/cysic-verifier/data/keys' to prevent data loss.${CL}"
echo -e "${INFO}${GN} To start Cysic-Verifier, run the command: 'docker compose -f $HOME/cysic-verifier/docker-compose.yml up -d'${CL}"
echo -e "${INFO}${GN} To stop Cysic-Verifier, run the command: 'docker compose -f $HOME/cysic-verifier/docker-compose.yml down'${CL}"
echo -e "${INFO}${GN} To restart Cysic-Verifier, run the command: 'docker compose -f $HOME/cysic-verifier/docker-compose.yml restart'${CL}"
echo -e "${INFO}${GN} To check the logs of Cysic-Verifier, run the command: 'docker compose -f $HOME/cysic-verifier/docker-compose.yml logs -fn 100'${CL}"