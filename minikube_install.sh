 #!/bin/bash
    read -p "Enter your username: " k8svc
    sudo apt update
    sudo apt install wget
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install  -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
    sudo rm -f ./minikube-linux-amd64
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    sudo rm -f ./kubectl
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    sudo apt install docker-ce -y
    sudo systemctl enable --now docker
    sudo usermod -aG docker ${k8svc} && newgrp docker
