#!/bin/bash

# Ignore TERM, HUP, INT
trap '' TERM HUP INT

VERBOSE=0
DESIRED_NAME=""
DESIRED_IP=""
HOST_ENTRY_NAME=""
HOST_ENTRY_IP=""

log_change() {
    logger "[CONFIGURE-HOST] $1"
    [ "$VERBOSE" -eq 1 ] && echo "[INFO] $1"
}

while [[ "$1" != "" ]]; do
    case "$1" in
        -verbose) VERBOSE=1 ;;
        -name) shift; DESIRED_NAME="$1" ;;
        -ip) shift; DESIRED_IP="$1" ;;
        -hostentry) shift; HOST_ENTRY_NAME="$1"; shift; HOST_ENTRY_IP="$1" ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

if [[ -n "$DESIRED_NAME" ]]; then
    CURRENT_NAME=$(hostname)
    if [[ "$CURRENT_NAME" != "$DESIRED_NAME" ]]; then
        echo "$DESIRED_NAME" > /etc/hostname
        hostname "$DESIRED_NAME"
        sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$DESIRED_NAME/" /etc/hosts
        log_change "Hostname changed from $CURRENT_NAME to $DESIRED_NAME"
    else
        [ "$VERBOSE" -eq 1 ] && echo "Hostname already set to $DESIRED_NAME"
    fi
fi

if [[ -n "$DESIRED_IP" ]]; then
    INTERFACE=$(ip route | awk '/default/ {print $5}')
    INTERFACE=${INTERFACE%@*}

    if [ -z "$INTERFACE" ]; then
        INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)
        INTERFACE=${INTERFACE%@*}
    fi

    if [ -z "$INTERFACE" ]; then
        echo "No suitable network interface found"
        exit 1
    fi

    CURRENT_IP=$(ip -4 addr show "$INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    if [[ "$CURRENT_IP" != "$DESIRED_IP" ]]; then
        NETPLAN_FILE=$(find /etc/netplan -type f | head -n 1)
        BACKUP_FILE="${NETPLAN_FILE}.bak"
        cp "$NETPLAN_FILE" "$BACKUP_FILE"

        cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses:
        - $DESIRED_IP/24
      nameservers:
        search: [home.arpa, localdomain]
        addresses: [1.1.1.1, 8.8.8.8]
      dhcp4: no
EOF

        if netplan apply 2>/dev/null; then
            log_change "IP changed from $CURRENT_IP to $DESIRED_IP on $INTERFACE"
        else
            echo "Failed to apply netplan configuration"
            cp "$BACKUP_FILE" "$NETPLAN_FILE"  # rollback
        fi
    else
        [ "$VERBOSE" -eq 1 ] && echo "IP already set to $DESIRED_IP"
    fi
fi

if [[ -n "$HOST_ENTRY_NAME" && -n "$HOST_ENTRY_IP" ]]; then
    HOSTS_LINE="$HOST_ENTRY_IP $HOST_ENTRY_NAME"
    if grep -qE "\s$HOST_ENTRY_NAME" /etc/hosts; then
        CURRENT_LINE=$(grep -E "\s$HOST_ENTRY_NAME" /etc/hosts)
        if [[ "$CURRENT_LINE" != "$HOSTS_LINE" ]]; then
            sed -i "s/.*$HOST_ENTRY_NAME/$HOSTS_LINE/" /etc/hosts
            log_change "Updated /etc/hosts entry for $HOST_ENTRY_NAME to $HOST_ENTRY_IP"
        else
            [ "$VERBOSE" -eq 1 ] && echo "/etc/hosts entry for $HOST_ENTRY_NAME is correct"
        fi
    else
        echo "$HOSTS_LINE" >> /etc/hosts
        log_change "Added /etc/hosts entry: $HOSTS_LINE"
    fi
fi
