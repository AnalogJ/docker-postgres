#!/usr/bin/env bash
VERSION=9.3

if [ "$DOCKER_POSTGRES_MODE" = "master" ];
then
    echo "wal_level = hot_standby # hot_standby is also acceptable (will log more)"     >> /etc/postgresql/$VERSION/main/conf.d/10master.conf
    echo "archive_mode = on"                                                            >> /etc/postgresql/$VERSION/main/conf.d/10master.conf
    echo "archive_command = 'envdir /etc/wal-e.d/env wal-e wal-push %p'"                >> /etc/postgresql/$VERSION/main/conf.d/10master.conf
    echo "archive_timeout = 60"                                                         >> /etc/postgresql/$VERSION/main/conf.d/10master.conf
else
    #slave mode (DEFAULT) readonly, will not actually create wal-e archives
    echo "wal_level = hot_standby # hot_standby is also acceptable (will log more)"     >> /etc/postgresql/$VERSION/main/conf.d/05slave.conf

fi

if ["$DOCKER_POSTGRES_RECOVER" = "true"];
then
    envdir /etc/wal-e.d/pull-env wal-e backup-fetch /var/lib/postgresql/$VERSION/main $DOCKER_POSTGRES_RECOVER_FROM

    echo "standby_mode     = 'on'"                                                      >> /var/lib/postgresql/$VERSION/main/recovery.conf
    #echo "primary_conninfo = 'host=$HOST user=$USER password=$PASSWORD'"               >> /var/lib/postgresql/$VERSION/main/recovery.conf
    echo "restore_command  = 'envdir /etc/wal-e.d/env wal-e wal-fetch \"%f\" \"%p\"'"   >> /var/lib/postgresql/$VERSION/main/recovery.conf
    echo "trigger_file     = '/var/lib/postgresql/$VERSION/main/trigger'"                    >> /var/lib/postgresql/$VERSION/main/recovery.conf
fi

#start phusion baseimage runner (https://github.com/phusion/baseimage-docker)
/sbin/my_init