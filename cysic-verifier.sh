#!/bin/bash
export DEBIAN_FRONTEND="noninteractive"
sudo apt-get update -qy > /dev/null 2>&1
sudo apt-get install -y -qq curl ca-certificates sudo > /dev/null 2>&1
source <(curl -s https://raw.githubusercontent.com/CryptoNodeID/helper-script/master/common.sh)
base_colors
header_info
color
catch_errors

REWARD_ADDRESS=""

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
install_Verifier() {
docker_check

mkdir -p $HOME/cysic-verifier
cd $HOME/cysic-verifier

tee Dockerfile > /dev/null << EOF
FROM ubuntu:noble

RUN apt-get update -qq && \\
    apt-get install -y -qq curl ca-certificates libc6 && \\
    curl -sL https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_linux.sh -o /root/setup_linux.sh

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
EOF
tee docker-compose.yml > /dev/null << EOF
services:
  cysic-verifier:
    container_name: cysic-verifier
    image: cysic-verifier:latest
    restart: unless-stopped
    volumes:
      - ${PWD}/data/cysic:/root/.cysic
      - ${PWD}/data/app:/app/data
    environment:
      - REWARD_ADDRESS=${REWARD_ADDRESS}
    stop_grace_period: 1m
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
msg_info "Building Cysic-Verifier..."
sudo docker build -t cysic-verifier:latest -f Dockerfile . >/dev/null 2>&1
msg_ok "Cysic-Verifier has been built."
rm -rf Dockerfile entrypoint.sh
msg_ok "Cysic-Verifier has been installed."

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
echo -e "${INFO}${GN} To start Cysic-Verifier, run the command: 'sudo docker compose -f $HOME/cysic-verifier/docker-compose.yml up -d'${CL}"
echo -e "${INFO}${GN} To stop Cysic-Verifier, run the command: 'sudo docker compose -f $HOME/cysic-verifier/docker-compose.yml down'${CL}"
echo -e "${INFO}${GN} To restart Cysic-Verifier, run the command: 'sudo docker compose -f $HOME/cysic-verifier/docker-compose.yml restart'${CL}"
echo -e "${INFO}${GN} To check the logs of Cysic-Verifier, run the command: 'sudo docker compose -f $HOME/cysic-verifier/docker-compose.yml logs -fn 100'${CL}"
}

install_Add-Verifier() {
if [ "$(docker images -q cysic-verifier:latest 2> /dev/null)" = "" ]; then
    msg_error "Cysic-Verifier image not found."
    init_cysic "Verifier"
else
    msg_ok "Cysic-Verifier image found."
fi
rm -rf $HOME/cysic-verifier/addr.list
REWARD_ADDRES=""
while true; do
  if REWARD_ADDRESS=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier Add" --inputbox "Input your reward address (enter blank to exit):" 8 60 3>&1 1>&2 2>&3); then
    if [ -z "$REWARD_ADDRESS" ]; then
        break
    elif [[ $REWARD_ADDRESS != 0x* ]]; then
        whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier Add" --msgbox "Error: Reward Address must start with 0x" 8 60
    else
        echo "$REWARD_ADDRESS" >> $HOME/cysic-verifier/addr.list
        if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Verifier Add" --yesno "\nReward Address: $REWARD_ADDRESS has been added.\n\nAdd another reward address?" 12 60); then
            continue
        else
            break
        fi
    fi
  else
    exit_script
  fi
done
if [ ! -s $HOME/cysic-verifier/addr.list ]; then
    msg_error "No reward address added or the file is blank."
    exit
  else
    for line in $(cat $HOME/cysic-verifier/addr.list); do
    msg_info "Creating docker-compose${i}.yml..."
    REWARD_ADDRESS=$line
    i=$(ls $HOME/cysic-verifier/ | grep -e "docker-compose" | wc -l)
    if [ -z $i ]; then
      i=1
    fi
tee docker-compose${i}.yml > /dev/null <<EOF
services:
  cysic-verifier-${i}:
    container_name: cysic-verifier-${i}
    image: cysic-verifier:latest
    restart: unless-stopped
    volumes:
      - ${PWD}/data/cysic:/root/.cysic
      - ${PWD}/data/app:/app/data
    environment:
      - REWARD_ADDRESS=${REWARD_ADDRESS}
    stop_grace_period: 1m
    network_mode: host
EOF
    i=$((i+1))
    msg_ok "docker-compose${i}.yml created successfully."
    done
fi
rm -f $HOME/cysic-verifier/addr.list
echo -e "${ROOTSSH}${YW} Please backup your Cysic-Verifier keys folder. '$HOME/cysic-verifier/data/keys' to prevent data loss.${CL}"
echo -e "${INFO}${GN} To start all Cysic-Verifier, run the command: 'for i in \$(ls -d -1 $HOME/cysic-verifier/* | grep -e "docker-compose"); do sudo docker compose -f \$i up -d; done'${CL}"
echo -e "${INFO}${GN} To stop all Cysic-Verifier, run the command: 'for i in \$(ls -d -1 $HOME/cysic-verifier/* | grep -e "docker-compose"); do sudo docker compose -f \$i down; done'${CL}"
}
install_Prover() {
if ! [ -x "$(command -v supervisorctl)" ]; then
    msg_info "Supervisor is not installed. Installing..."
    sudo apt-get install -qy supervisor > /dev/null 2>&1
    msg_ok "Supervisor has been installed."
fi
msg_info "Initializing Cysic-Prover... *This may take some time, go get a cup of coffee*"
curl -sL https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_prover.sh > $HOME/setup_prover.sh && bash $HOME/setup_prover.sh ${REWARD_ADDRESS} > /dev/null 2>&1
msg_ok "Cysic-Prover Initialized."
msg_info "Configuring Supervisor..."
cd $HOME/cysic-prover
tee cysic-prover.conf > /dev/null <<EOF
[program:cysic]
command=/root/cysic-prover/prover
autostart=true
autorestart=true
stderr_logfile=/root/cysic-prover/cysic-prover.log
stdout_logfile=/root/cysic-prover/cysic-prover.log
environment=LD_LIBRARY_PATH="/root/cysic-prover:\$LD_LIBRARY_PATH",CHAIN_ID="534352:\$CHAIN_ID"
directory=/root/cysic-prover
EOF
echo -e "\n[include]\nfiles = ${HOME}/cysic-prover/cysic-prover.conf\n" >> /etc/supervisor/supervisord.conf
supervisorctl reread > /dev/null 2>&1
msg_ok "Supervisor has been configured."
if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Prover" --yesno "Do you want to run the Cysic-Prover?" 10 60); then
    supervisorctl update > /dev/null 2>&1
    supervisorctl start cysic > /dev/null 2>&1
    msg_ok "Cysic-Verifier has been started."
fi

echo -e "${ROOTSSH}${YW} Please backup your Cysic-Prover keys folder. '$HOME/cysic-prover/~/.cysic/assets' to prevent data loss.${CL}"
echo -e "${INFO}${GN} To start Cysic-Prover, run the command: 'sudo supervisorctl start cysic'${CL}"
echo -e "${INFO}${GN} To stop Cysic-Prover, run the command: 'sudo supervisorctl stop cysic'${CL}"
echo -e "${INFO}${GN} To check Cysic-Prover logs, run the command: 'sudo supervisorctl tail cysic stderr'${CL}"
}
init_cysic() {
if (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-${1}" --yesno "This script will install the Cysic-${1}. Do you want to continue?" 10 60); then
    while [ -z "$REWARD_ADDRESS" ]; do
      if REWARD_ADDRESS=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-${1}" --inputbox "Input your reward address (EVM starting with 0x):" 8 60 3>&1 1>&2 2>&3); then
        if [[ $REWARD_ADDRESS != 0x* ]]; then
            whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-${1}" --msgbox "Error: Reward Address must start with 0x" 8 60
            REWARD_ADDRESS=""
        elif (whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-${1}" --yesno "\nReward Address: $REWARD_ADDRESS\n\nContinue with the installation?" 10 60); then
            break
        else
            REWARD_ADDRESS=""
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
    choice=$(whiptail --backtitle "CryptoNodeID Helper Scripts" --title "Cysic-Node" --menu "Choose the type of Cysic-Node to install:" 10 70 4 \
        "Verifier" "     Install the Cysic-Verifier (Default)" \
        "Add Verifier" "     Need to install Cysic-Verifier first" \
        "Prover" "     Install the Cysic-Prover" \
        "Exit" "     Exit the script"  --nocancel --default-item "Verifier" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
      echo -e "${CROSS}${RD} Menu canceled. Exiting.${CL}"
      exit 0
    fi

    case $choice in
        "Verifier")
          init_cysic "Verifier"
          break
          ;;
        "Add Verifier")
          install_Add-Verifier
          break
          ;;
        "Prover")
          init_cysic "Prover"
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
