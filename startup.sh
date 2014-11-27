#!/usr/bin/env bash
VERSION=9.3

CONFIG_DIR=/etc/postgresql/$VERSION/main
DATA_DIR=/var/lib/postgresql/$VERSION/main

# create conf.d folder to load postgres config files.
mkdir -m 755 -p $CONFIG_DIR/conf.d/

if [ "$DOCKER_POSTGRES_MODE" = "leader" ];
then
    echo "wal_level = hot_standby # hot_standby is also acceptable (will log more)"     >> $CONFIG_DIR/conf.d/10leader.conf
    echo "archive_mode = on"                                                            >> $CONFIG_DIR/conf.d/10leader.conf
    echo "archive_command = 'envdir /etc/wal-e.d/env wal-e wal-push %p'"                >> $CONFIG_DIR/conf.d/10leader.conf
    echo "archive_timeout = 60"                                                         >> $CONFIG_DIR/conf.d/10leader.conf
else
    #follower mode (DEFAULT) readonly, will not actually create wal-e archives
    echo "wal_level = hot_standby # hot_standby is also acceptable (will log more)"     >> $CONFIG_DIR/conf.d/10follower.conf
    echo "hot_standby = on"                                                             >> $CONFIG_DIR/conf.d/10follower.conf
fi

if [ "$DOCKER_POSTGRES_RECOVER" = "true" ];
then
    envdir /etc/wal-e.d/env wal-e backup-fetch $DATA_DIR $DOCKER_POSTGRES_RECOVER_FROM

    echo "standby_mode     = 'on'"                                                      >> $DATA_DIR/recovery.conf
    #echo "primary_conninfo = 'host=$HOST user=$USER password=$PASSWORD'"               >> $DATA_DIR/recovery.conf
    echo "restore_command  = 'envdir /etc/wal-e.d/env wal-e wal-fetch \"%f\" \"%p\"'"   >> $DATA_DIR/recovery.conf
    echo "trigger_file     = '/var/lib/postgresql/$VERSION/main/trigger'"               >> $DATA_DIR/recovery.conf
fi

#start phusion baseimage runner (https://github.com/phusion/baseimage-docker)
/sbin/my_init