#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root / Пожалуйста, запустите скрипт с правами root, т.е. через sudo или su"
  exit 1
fi

set -x 
cp mai-shedule-bot.sh /usr/local/bin/mai-shedule-bot
chmod +x /usr/local/bin/mai-shedule-bot

set +x

echo "Теперь отредактируйте settings.conf"
