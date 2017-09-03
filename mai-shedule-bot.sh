#!/bin/bash

# отслеживание изменений в расписании МАИ
# автор: Михаил Новоселов, https://github.com/mikhailnov
# перед использованием заполните конфигурационный файл settings.conf
# crontab.example - пример расписание для запуска бота по cron
# sipcmd: https://github.com/tmakkonen/sipcmd

function make_sip_calls {
	for i in `echo $sip_numbers`
	do
		sipcmd -u $sip_login -c $sip_password -P sip -w $sip_server -x "c${i};ws50;h" -o logs/`date +%s`_$i.log
		sleep 15
	done	
}

work_dir="data"
if [ -f "$work_dir" ]
	then
		echo >/dev/null
	else
		mkdir -p "$work_dir"
fi
if [ -f "$work_dir/checks" ]
	then
		echo >/dev/null
	else
		touch "$work_dir/checks"
		echo 0 >"$work_dir/checks"
fi
if [ -f "$work_dir/logs" ]
	then
		echo >/dev/null
	else
		mkdir -p "$work_dir/logs"
fi
if [ -f "settings.conf" ]
	then
		echo >/dev/null
	else
		echo "не найден файл настроек settings.conf, не можем продолжить работать, exit 1"
		exit 1
fi

# подгрузим настройки
source settings.conf
cd "$work_dir"
week_num=$((`date +%V` -34))

current_check_unix_date="`date +%s`"
wget -q -O- "https://mai.ru/education/schedule/detail.php?group=${MAI_group}&week=$week_num" | grep -v sessid | tee ${current_check_unix_date}_page.html >/dev/null

previous_check_unix_date="`cat checks | tail -n 1 | awk '{print $1}'`"
previous_check_week_num="`cat checks | tail -n 1 | awk '{print $2}'`"
echo "$current_check_unix_date $week_num" >>checks

hash_previous="`md5sum ${previous_check_unix_date}_page.html | awk '{print $1}'`"
hash_current="`md5sum ${current_check_unix_date}_page.html | awk '{print $1}'`"

if [ "$hash_previous" == "$hash_current" ]
	then
		echo "Изменений в расписании на учебную неделю номер $week_num не обнаружено"
		exit 0
	else
		if [ "$previous_check_week_num" == "$week_num" ]
			then
				echo "Расписание изменилось!!!"
				make_sip_calls
			else
				echo "Наступила следующая неделя, потому никому не звоним"
				# у нас будет запуск бота, допустим, через час после наступления следующей недели, при этом первом запуске в неделю он попадет сюда, в наступление след. недели, однако уже при следующем запуске, например, в 8 утра в понедельник он позвонит, если расписание изменится относительно предыдущей проверки, то есть, если его рано утром в понедельник изменят, он позвонит
		fi
fi
