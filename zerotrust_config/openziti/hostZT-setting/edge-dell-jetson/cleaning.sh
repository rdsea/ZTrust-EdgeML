#!/bin/bash

set -e

# Backup before modifying
cp /etc/hosts /etc/hosts.bak

# Remove entries
sed -i '/ctrl\.cloud\.hong3nguyen\.com/d' /etc/hosts

sed -i '/router\.cloud\.hong3nguyen\.com/d' /etc/hosts

echo "Removed OpenZiti DNS entries from /etc/hosts"
