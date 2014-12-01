USER=${USER:-super}
PASS=${PASS:-$(pwgen -s -1 16)}

CONFIG_DIR=/etc/postgresql/9.3/main

pre_start_action() {
  # Echo out info to later obtain by running `docker logs container_name`
  echo "POSTGRES_USER=$USER"
  echo "POSTGRES_PASS=$PASS"
  echo "POSTGRES_DATA_DIR=$DATA_DIR"
  if [ ! -z $DB ];then echo "POSTGRES_DB=$DB";fi

  # test if DATA_DIR has content
  if [[ ! "$(ls -A $DATA_DIR)" ]]; then
      echo "Initializing PostgreSQL at $DATA_DIR"

      # Copy the data that we generated within the container to the empty DATA_DIR.
      cp -R /var/lib/postgresql/9.3/main/* $DATA_DIR
  fi

  # Fetch backups if in foller mode.
  if [ "$DOCKER_POSTGRES_RECOVER" = "true" ];
  then
    #Backup recovery can only happen in the first run of the docker container.
    #We will fetch the backup and put it in the standard location, /var/lib/postgresql
    #When the supervisor service starts running, the first_run script will copy the contents into the /data/ folder.
    envdir /etc/wal-e.d/env wal-e backup-fetch $DATA_DIR $DOCKER_POSTGRES_RECOVER_FROM

    tee $DATA_DIR/recovery.conf <<-EOF
standby_mode     = 'on'
restore_command  = 'envdir /etc/wal-e.d/env wal-e wal-fetch "%f" "%p"'
trigger_file     = '/data/trigger'
EOF
    chown postgres:postgres $DATA_DIR/recovery.conf
  fi

  # Ensure postgres owns the DATA_DIR
  chown -R postgres $DATA_DIR
  # Ensure we have the right permissions set on the DATA_DIR
  chmod -R 700 $DATA_DIR

  # create conf.d folder to load postgres config files.
  mkdir -m 755 -p $CONFIG_DIR/conf.d/

  # create additional configuration depending on if the server is running as a leader/follower
  if [ "$DOCKER_POSTGRES_MODE" = "leader" ];
  then
    tee $CONFIG_DIR/conf.d/10leader.conf <<-EOF
wal_level = hot_standby # hot_standby is also acceptable (will log more)
archive_mode = on
archive_command = 'envdir /etc/wal-e.d/env wal-e wal-push %p'
archive_timeout = 60
EOF
  else
    #follower mode (DEFAULT) readonly, will not actually create wal-e archives
    tee $CONFIG_DIR/conf.d/10follower.conf <<-EOF
wal_level = hot_standby # hot_standby is also acceptable (will log more)
hot_standby = on
EOF
  fi

  #Ensure ownership
  chown -R root:root         /etc/cron.{d,daily,hourly,monthly,weekly}
  chmod -R 755               /etc/cron.{d,daily,hourly,monthly,weekly}
  chown -R root:postgres     /etc/wal-e.d
  chmod -R 750               /etc/wal-e.d
  chown -R postgres:postgres $CONFIG_DIR
  #chmod -R 700               /etc/postgresql/9.3/main
}

post_start_action() {
  if [ "$DOCKER_POSTGRES_MODE" = "follower" ];
  then
    echo "Skipping - Running as a follower, cannot run sql queries to create database/user"
    echo "Removing /firstrun file and continuing"
    rm /firstrun
    return
  fi

  echo "Creating the superuser: $USER"
  setuser postgres psql -q <<-EOF
    DROP ROLE IF EXISTS $USER;
    CREATE ROLE $USER WITH ENCRYPTED PASSWORD '$PASS';
    ALTER USER $USER WITH ENCRYPTED PASSWORD '$PASS';
    ALTER ROLE $USER WITH SUPERUSER;
    ALTER ROLE $USER WITH LOGIN;
EOF

  # create database if requested
  if [ ! -z "$DB" ]; then
    for db in $DB; do
      echo "Creating database: $db"
      setuser postgres psql -q <<-EOF
      CREATE DATABASE $db WITH OWNER=$USER ENCODING='UTF8';
      GRANT ALL ON DATABASE $db TO $USER
EOF
    done
  fi

  if [[ ! -z "$EXTENSIONS" && ! -z "$DB" ]]; then
    for extension in $EXTENSIONS; do
      for db in $DB; do
        echo "Installing extension for $db: $extension"
        # enable the extension for the user's database
        setuser postgres psql $db <<-EOF
        CREATE EXTENSION "$extension";
EOF
      done
    done
  fi

  rm /firstrun
}
