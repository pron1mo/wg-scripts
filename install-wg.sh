#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

## Install WG and deps
echo "### Installing WireGuard and dependencies."
apt-get update && apt-get install -y wireguard qrencode iptables-persistent

## Generate server key
echo "### Generating server keys."
wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key

## Putting key in conf and place it in /etc/wireguard/
echo "### Configuring WG."
private_key=$(cat /etc/wireguard/server_private_key)
sed "s|:SERVER_PRIV_KEY:|$private_key|" ./wg0-server.example.conf| tee /etc/wireguard/wg0.conf

## Starting WireGuard wg0
echo "### Starting WireGuard (wg0)."
wg-quick up wg0

## Enabling WG Daemon
echo "### Starting WireGuard (wg0)."
systemctl enable wg-quick@wg0.service

## Configuring iptables
echo "### Configuring iptables."

# Track VPN Connection
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# VPN Traffic
iptables -A INPUT -p udp -m udp --dport 51820 -m conntrack --ctstate NEW -j ACCEPT

# Forwarding/NAT
iptables -A FORWARD -i wg0 -o wg0 -m conntrack --ctstate NEW -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

systemctl enable netfilter-persistent
netfilter-persistent save


echo "### Installing Complete!"

