export UBUNTU_LTS=jammy
#chmod +x install-ziti-edge-tunnel.sh

apt update
apt install curl, gpg -y

curl -sSLf https://get.openziti.io/tun/package-repos.gpg |
  gpg --dearmor --output /usr/share/keyrings/openziti.gpg

chmod -c +r /usr/share/keyrings/openziti.gpg

echo "deb [signed-by=/usr/share/keyrings/openziti.gpg] https://packages.openziti.org/zitipax-openziti-deb-stable $UBUNTU_LTS main" |
  tee /etc/apt/sources.list.d/openziti.list >/dev/null

apt update

apt install -y ziti-edge-tunnel

