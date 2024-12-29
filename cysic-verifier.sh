#!/bin/bash
source <(curl -s https://raw.githubusercontent.com/CryptoNodeID/helper-script/master/common.sh)

header_info

# Check if the shell is using bash
shell_check

# Check and install docker if not available
if ! command -v docker &> /dev/null; then
    msg_info "Docker is not installed. Installing Docker..."
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

CHOICE=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --menu "This script will install the Cysic-Verifier. Do you want to continue?" 14 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    ;;
  no)
    exit 0
    ;;
  esac

REWARD_ADDRESS=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --inputbox "Input your reward address (EVM):" 8 60 "0x" 3>&1 1>&2 2>&3)
if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --yesno "\nReward Address: $REWARD_ADDRESS\n\nContinue with the installation?" 10 60); then
    msg_info "Installing Cysic-Verifier"
    break
else
    exit 0
fi

mkdir -p $HOME/cysic-verifier
cd $HOME/cysic-verifier

tee Dockerfile << EOF
FROM debian:bullseye-slim AS builder
ARG REWARD_ADDRESS
RUN apt update && \
    apt install -y curl ca-certificates && \            
    curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_linux.sh > /root/setup_linux.sh

WORKDIR /root/
RUN bash ./setup_linux.sh $REWARD_ADDRESS

FROM ubuntu:jammy

COPY --from=builder /root/cysic-verifier /root/cysic-verifier

RUN apt update && \
    apt install -y ca-certificates libc6

WORKDIR /root/cysic-verifier

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
EOF
tee docker-compose.yml << EOF
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
      - ${PWD}/data:/root/.cysic
    stop_grace_period: 5m
EOF
tee entrypoint.sh << EOF
#!/bin/sh
cd /root/cysic-verifier
bash ./start.sh
EOF

CHOICE=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --menu "Do you want to run the Cysic-Verifier?" 14 58 2 \
    "yes" " " \
    "no" " " 3>&2 2>&1 1>&3)
  case $CHOICE in
  yes)
    if [ "$(docker images -q cysic-verifier-cysic-verifier 2> /dev/null)" != "" ]; then
        sudo docker rmi cysic-verifier-cysic-verifier -f        
    fi
    sudo docker compose -f $HOME/cysic-verifier/docker-compose.yml up -d
    ;;
  no)
    exit 0
    ;;
  esac

msg_ok "Cysic-Verifier installed successfully."

whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier" --msgbox "Please backup your Cysic-Verifier data folder. \n'$HOME/cysic-verifier/data' to prevent data loss.\n\nTo start Cysic-Verifier, run the command: \n'docker compose -f $HOME/cysic-verifier/docker-compose.yml up -d'\n\nTo stop Cysic-Verifier, run the command: \n'docker compose -f $HOME/cysic-verifier/docker-compose.yml down'\n\nTo restart Cysic-Verifier, run the command: \n'docker compose -f $HOME/cysic-verifier/docker-compose.yml restart'\n\nTo check the logs of Cysic-Verifier, run the command: \n'docker compose -f $HOME/cysic-verifier/docker-compose.yml logs -fn 100'" 20 81