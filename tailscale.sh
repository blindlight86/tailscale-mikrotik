#!/bin/bash

set -m

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# Set root password
echo "root:${PASSWORD}" | chpasswd

# Install routes
IFS=',' read -ra SUBNETS <<< "${ADVERTISE_ROUTES}"
for s in "${SUBNETS[@]}"; do
  ip route add "$s" via "${CONTAINER_GATEWAY}"
  iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  iptables -A FORWARD -i tailscale0 -o eth0 -j ACCEPT
  iptables -A FORWARD -i eth0 -o tailscale0 -j ACCEPT
done

# Set login server for tailscale
if [[ -z "$LOGIN_SERVER" ]]; then
	LOGIN_SERVER=https://controlplane.tailscale.com
fi

# Start tailscaled and bring tailscale up
/usr/local/bin/tailscaled &
until /usr/local/bin/tailscale up \
  --reset --authkey=${AUTH_KEY} \
	--login-server ${LOGIN_SERVER} \
	--advertise-routes="${ADVERTISE_ROUTES}" \
 	--accept-routes=true \
 	--accept-dns=false \
  ${TAILSCALE_ARGS}
do
    sleep 0.1
done
echo Tailscale started


fg %1
