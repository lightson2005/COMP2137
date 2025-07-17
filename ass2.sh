#!/bin/bash

set -e

echo "Script started"

# Configuration
TARGETIP="192.168.16.21"
INTERFACE=$(ip -o -4 addr show | grep 192.168.16 | awk '{print $2}' | head -n 1)
HOSTENTRY="$TARGETIP server1"
EXTRASSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"
USERLIST=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

log() {
  echo
  echo "== $1 =="
}

install_packages() {
  log "Installing apache2 and squid"
  for pkg in apache2 squid; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
      apt-get update -qq
      apt-get install -y $pkg
      echo "$pkg installed"
    else
      echo "$pkg already installed"
    fi
  done
}

configure_netplan() {
  log "Checking netplan configuration"
  CONFIGFILE=$(find /etc/netplan -name "*.yaml" | head -n 1)

  if [ -z "$CONFIGFILE" ]; then
    echo "ERROR: No netplan config file found"
    return 1
  fi

  echo "Using netplan config file: $CONFIGFILE"

  if grep -q "$TARGETIP" "$CONFIGFILE"; then
    echo "Netplan already configured with $TARGETIP"
  else
    INTERFACE=$(ip -o -4 addr show | grep 192.168.16 | awk '{print $2}' | head -n 1)
    if [ -z "$INTERFACE" ]; then
      echo "ERROR: Could not detect the correct interface"
      return 1
    fi

    cat > "$CONFIGFILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      addresses: [$TARGETIP/24]
      dhcp4: no
EOF

    netplan apply
    echo "Netplan configuration applied"
  fi
}

hosts_file() {
  log "Updating /etc/hosts"
  sed -i "/server1/d" /etc/hosts
  echo "$HOSTENTRY" >> /etc/hosts
  echo "/etc/hosts updated"
}

user_ssh_keys() {
  local user=$1
  local ssh_dir="/home/$user/.ssh"

  mkdir -p "$ssh_dir"
  chown "$user:$user" "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [ ! -f "$ssh_dir/id_rsa.pub" ]; then
    sudo -u "$user" ssh-keygen -q -t rsa -N "" -f "$ssh_dir/id_rsa"
  fi

  if [ ! -f "$ssh_dir/id_ed25519.pub" ]; then
    sudo -u "$user" ssh-keygen -q -t ed25519 -N "" -f "$ssh_dir/id_ed25519"
  fi

  cat "$ssh_dir/id_rsa.pub" "$ssh_dir/id_ed25519.pub" > "$ssh_dir/authorized_keys"

  if [ "$user" = "dennis" ]; then
    echo "$EXTRASSHKEY" >> "$ssh_dir/authorized_keys"
  fi

  chown "$user:$user" "$ssh_dir"/*
  chmod 600 "$ssh_dir"/*
}

user_accounts() {
  log "Creating user accounts and SSH keys"
  for user in "${USERLIST[@]}"; do
    if ! id "$user" &>/dev/null; then
      useradd -m -s /bin/bash "$user"
      echo "User $user created"
    else
      echo "User $user already exists"
    fi

    if [ "$user" = "dennis" ]; then
      usermod -aG sudo dennis
      echo "Added dennis to sudo group"
    fi

    user_ssh_keys "$user"
  done
}

# Execute steps
install_packages
configure_netplan
hosts_file
user_accounts

log "Script Completed"
