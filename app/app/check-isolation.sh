#!/bin/sh
set -eu
{
 echo 'IDENTITY'; id; hostname; pwd
 echo 'MOUNTS'; awk '{print $5}' /proc/self/mountinfo | sort -u | head -35
 echo 'PATHS'; for p in /home/sandbox /memory /skills /home/app /home/feed /home/deskguest /bridge /etc; do if [ -e "$p" ]; then echo "$p: visible"; else echo "$p: absent"; fi; done
 echo 'NETWORK'; readlink /proc/self/ns/net; ip route 2>&1 || true
 echo 'PROCESSES'; ps -eo comm | sort -u | head -35
} > /home/deskguest/isolation-check.txt
