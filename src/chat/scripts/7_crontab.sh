#!/usr/bin/env bash

( crontab -l 2>/dev/null; echo '0 4 * * 0 /home/ubuntu/.local/bin/hermes update >> /home/ubuntu/.hermes/update.log 2>&1' ) | crontab -
( crontab -l 2>/dev/null; echo '0 5 * * 0 cd /home/ubuntu/docker && docker compose pull && docker compose up -d' ) | crontab -