#!/usr/bin/env bash

CONFIG_DIR=/etc/postgresql/9.3/main
DATA_DIR=/var/lib/postgresql/9.3/main

# create conf.d folder to load postgres config files.
mkdir -m 755 -p $CONFIG_DIR/conf.d/

if [ "$DOCKER_POSTGRES_MODE" = "leader" ];
then
    tee $CONFIG_DIR/conf.d/10leader.conf <<EOF
    wal_level = hot_standby # hot_standby is also acceptable (will log more)
    archive_mode = on
    archive_command = 'envdir /etc/wal-e.d/env wal-e wal-push %p'
    archive_timeout = 60
EOF
else
    #follower mode (DEFAULT) readonly, will not actually create wal-e archives
    tee $CONFIG_DIR/conf.d/10follower.conf <<EOF
    wal_level = hot_standby # hot_standby is also acceptable (will log more)
    hot_standby = on
EOF
fi

if [ "$DOCKER_POSTGRES_RECOVER" = "true" ] && [ -e /firstrun ];
then
    #Backup recovery can only happen in the first run of the docker container.
    #We will fetch the backup and put it in the standard location, /var/lib/postgresql
    #When the supervisor service starts running, the first_run script will copy the contents into the /data/ folder.
    envdir /etc/wal-e.d/env wal-e backup-fetch $DATA_DIR $DOCKER_POSTGRES_RECOVER_FROM

    tee $DATA_DIR/recovery.conf <<EOF
    standby_mode     = 'on'
    restore_command  = 'envdir /etc/wal-e.d/env wal-e wal-fetch \"%f\" \"%p\"'
    trigger_file     = '/data/trigger'
EOF
fi

#start phusion baseimage runner (https://github.com/phusion/baseimage-docker)
/sbin/my_init