#!/bin/bash
# /usr/bin/blynk
# use with blynk.service

APP_DIR=/opt/blynk

PID=/var/run/blynk.pid
LOG=/var/log/blynk.log
ERROR=/var/log/blynk-error.log

COMMAND="java -jar "$APP_DIR"/server.jar -serverConfig "$APP_DIR"/server.properties"

status() {
	echo 
	echo "==== Status"
	echo $COMMAND	
	if [ -f $PID ]
	then
		echo
		echo "Pid file: $( cat $PID ) [$PID]"
		echo
		ps -ef | grep -v grep | grep $( cat $PID )
	else
		echo
		echo "No Pid file"
	fi
}

start() {
	if [ -f $PID ]
	then
		echo
		echo "Already started. PID: [$( cat $PID )]"
	else
		echo "==== Starting"
		echo $COMMAND
		touch $PID
		if nohup $COMMAND >>$LOG 2>&1 &
		then
			echo $! >$PID
			echo "Done"
			echo "$(date '+%Y-%m-%d %X'): START" >>$LOG
		else
			echo "Error"
			/bin/rm $PID
		fi
	fi
}

kill_cmd() {
	SIGNAL=""; MSG="Killing "
	while true
	do
		LIST=`ps -ef | grep -v grep | grep server.jar | awk '{print$1}'`
		if [ "$LIST" ]
		then
			echo; echo " $MSG $LIST" ; echo
			echo $LIST | xargs kill $SIGNAL
			sleep 2
			SIGNAL="-9" ; MSG="Killing $SIGNAL"
			if [ -f $PID ]
			then
				/bin/rm $PID
			fi
		else
			echo; echo "All killed" ; echo
			break
		fi
	done
}

stop() {
    echo "==== Stop"

    if [ -f $PID ]
    then
        if kill $( cat $PID )
        then echo "Done."
             echo "$(date '+%Y-%m-%d %X'): STOP" >>$LOG
        fi
        /bin/rm $PID
        kill_cmd
    else
        echo "No pid file. Already stopped?"
    fi
}

case "$1" in
    'start')
            start
            ;;
    'stop')
            stop
            ;;
    'restart')
            stop ; echo "Sleeping..."; sleep 1 ;
            start
            ;;
    'status')
            status
            ;;
    *)
            echo
            echo "Usage: $0 { start | stop | restart | status }"
            echo
            exit 1
            ;;
esac

exit 0