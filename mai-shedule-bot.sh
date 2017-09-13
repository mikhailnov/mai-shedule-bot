#!/bin/bash

# лицензия/license GPL v3
# отслеживание изменений в расписании МАИ
# автор: Михаил Новоселов, https://github.com/mikhailnov
# перед использованием заполните конфигурационный файл settings.conf
# crontab.example - пример расписание для запуска бота по cron
# sipcmd: https://github.com/tmakkonen/sipcmd

echo " "
echo "MAI Shedule bot started at `date` "
echo " "

if echo "$@" | grep 'test'
	then
		echo "Запуск в тестовом режиме"
		work_mode="test"
	else
		echo "Запуск в продакшн режиме"
		work_mode="production"
fi
echo " "

function make_sip_calls {
	for i in `echo $sip_numbers`
	do
		# грязный хак с завершением работы всех sipcmd, т.к. после звонков некотоыре из них продолжают висеть в памяти и занимать порт 5060, делая дальнейшие звонки невозможными
		pkill -9 sipcmd
		sipcmd -u $sip_login -c $sip_password -P sip -w $sip_server -x "c${i};ws50;h" -o logs/`date +%s`_$i.log
		sleep 60
		pkill -9 sipcmd
	done	
}

primary_dir="$HOME/mai-shedule-bot"
if [ -f "$primary_dir" ]
	then
		echo >/dev/null
	else
		mkdir -p "$primary_dir"
fi
work_dir="$primary_dir/data"
if [ -f "$work_dir" ]
	then
		echo >/dev/null
	else
		mkdir -p "$work_dir"
fi
if [ -f "$work_dir/checks.csv" ]
	then
		echo >/dev/null
	else
		touch "$work_dir/checks.csv"
		echo 0 >"$work_dir/checks.csv"
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

cd "$primary_dir"
# подгрузим настройки
if source settings.conf $work_mode
	then 
		echo >/dev/null
	else
		"Нет файла настроек `pwd`/settings.conf , exit 1"
		exit 1
fi

cd "$work_dir"
# т.к. учебный год начался с 35-ой недели, вычитаем из номера текущей недели 34 и получаем номер учебной недели в расписании
week_num=$((`date +%V` -34))

current_check_unix_date="`date +%s`"
if [ "$work_mode" == "production" ]
	then
		# production mode
		wget -q -O- "https://mai.ru/education/schedule/detail.php?group=${MAI_group}&week=$week_num" | grep -v sessid | tee ${current_check_unix_date}_page.html >/dev/null
	else
		# local test mode
		wget -q -O- "http://localhost/mai-shedule-bot/index.html?group=${MAI_group}&week=$week_num" | grep -v sessid | tee ${current_check_unix_date}_page.html >/dev/null
fi

previous_check_unix_date="`cat checks.csv | tail -n 1 | awk -F ";" '{print $1}'`"
previous_check_week_num="`cat checks.csv | tail -n 1 | awk -F ";" '{print $2}'`"

hash_previous="`md5sum ${previous_check_unix_date}_page.html | awk -F " " '{print $1}'`"
hash_current="`md5sum ${current_check_unix_date}_page.html | awk -F " " '{print $1}'`"

if [ "$hash_previous" == "$hash_current" ]
	then
		echo "Изменений в расписании на учебную неделю номер $week_num не обнаружено"
		check_result="not_changed"
	else
		if [ "$previous_check_week_num" == "$week_num" ]
			then
				echo "Расписание изменилось!!!"
				check_result="changed"
				# повторим обзвон еще раз, на всякий случай, вдруг в первый раз звонки не прошли (sipcmd странно работает, в идеале надо отслеживать состояние каждого звонка)
				for b in {1..2}
				do
					make_sip_calls
				done
			else
				echo "Наступила следующая неделя, потому никому не звоним"
				check_result="new_week"
				# у нас будет запуск бота, допустим, через час после наступления следующей недели, при этом первом запуске в неделю он попадет сюда, в наступление след. недели, однако уже при следующем запуске, например, в 8 утра в понедельник он позвонит, если расписание изменится относительно предыдущей проверки, то есть, если его рано утром в понедельник изменят, он позвонит
		fi
fi

echo "${current_check_unix_date};${week_num};${check_result};${work_mode};`date`" >>checks.csv
