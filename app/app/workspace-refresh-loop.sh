#!/usr/bin/env bash
# Isolated guest-only hourly refresh of already cloned public repos.
while true; do
  /usr/bin/bash /home/app/refresh-workspace-guest.sh
  sleep 3600
done
