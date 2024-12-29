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

while [ -z "$REWARD_ADDRESS" ]; do
    REWARD_ADDRESS=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --inputbox "Input your reward address (EVM):" 8 60 "0x" 3>&1 1>&2 2>&3)
    if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --yesno "\nReward Address: $REWARD_ADDRESS\n\nContinue with the installation?" 10 60); then
        break
    else
        REWARD_ADDRESS=""
    fi
done
mkdir -p $HOME/cysic-verifier
cd $HOME/cysic-verifier

tee Dockerfile > /dev/null << EOF
FROM debian:bullseye-slim AS builder
ARG REWARD_ADDRESS
RUN apt update -qq && \
    apt install -y -qq curl ca-certificates && \
    curl -sL https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_linux.sh > /root/setup_linux.sh

WORKDIR /root/
RUN bash ./setup_linux.sh $REWARD_ADDRESS

FROM ubuntu:jammy

COPY --from=builder /root/cysic-verifier /root/cysic-verifier

RUN apt update -qq && \
    apt install -y -qq ca-certificates libc6

WORKDIR /root/cysic-verifier

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
EOF
tee docker-compose.yml > /dev/null << EOF
services:
  cysic-verifier:
    container_name: cysic-verifier
    build:
      context: .
      dockerfile: Dockerfile
      args:
        - REWARD_ADDRESS=$REWARD_ADDRESS
    restart: unless-stopped
    volumes:
      - ${PWD}/data/.cysic:/root/.cysic
      - ${PWD}/data/app:/app/data
    stop_grace_period: 5m
EOF
tee entrypoint.sh > /dev/null << EOF
#!/bin/sh
cd /root/cysic-verifier
bash ./start.sh
EOF
msg_ok "Cysic-Verifier has been installed."
}
if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --yesno "This script will install the Cysic-Verifier. Do you want to continue?" 10 60); then
    install
else
    exit 0
fi

if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --yesno "Do you want to run the Cysic-Verifier?" 10 60); then
    if [ "$(docker ps -q -f name=cysic-verifier --no-trunc | wc -l)" -ne "0" ]; then
        msg_error "Cysic-Verifier is already running."
        sudo docker stop cysic-verifier
        msg_ok "Cysic-Verifier has been stopped."
    fi
    if [ "$(docker images -q cysic-verifier-cysic-verifier 2> /dev/null)" != "" ]; then
        msg_error "Old Cysic-Verifier found."
        sudo docker rmi cysic-verifier-cysic-verifier -f
        msg_ok "Old Cysic-Verifier has been removed."        
    fi
    msg_ok "Cysic-Verifier check complete."
    msg_info "Starting Cysic-Verifier..."
    sudo docker compose -f $HOME/cysic-verifier/docker-compose.yml up -d
    msg_ok "Cysic-Verifier started successfully.\n"
fi

echo -e "${ROOTSSH}${YW} Please backup your Cysic-Verifier keys folder. '$HOME/cysic-verifier/data/keys' to prevent data loss.${CL}"
echo -e "${INFO}${GN} To start Cysic-Verifier, run the command: 'docker compose -f $HOME/cysic-verifier/docker-compose.yml up -d'${CL}"
echo -e "${INFO}${GN} To stop Cysic-Verifier, run the command: 'docker compose -f $HOME/cysic-verifier/docker-compose.yml down'${CL}"
echo -e "${INFO}${GN} To restart Cysic-Verifier, run the command: 'docker compose -f $HOME/cysic-verifier/docker-compose.yml restart'${CL}"
echo -e "${INFO}${GN} To check the logs of Cysic-Verifier, run the command: 'docker compose -f $HOME/cysic-verifier/docker-compose.yml logs -fn 100'${CL}"