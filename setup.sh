#!/bin/bash

# Disable SELinux
sudo setenforce 0

# Disable SELinux permanently
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# Install nano and wget
sudo yum -y install nano wget

# These three lines download Docker: Community Edition
# I want the community edition because it's a later version of the regular Docker
sudo yum -y install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum -y install docker-ce

# Enable docker to automatically start on boot
sudo systemctl enable docker
sudo systemctl start docker

# Add Google's DNS to the Docker daemon; this allows Docker containers to connect to the internet
echo '{"dns": ["8.8.8.8", "8.8.4.4"]}' | sudo tee --append /etc/docker/daemon.json > /dev/null

# Add the user to the docker group and then reboot to apply the changes
sudo usermod -aG docker $USER
sudo reboot
