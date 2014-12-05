#!/bin/bash -x
# Starts up postgresql within the container.

# Stop on error
set -e

DATA_DIR=/data

if [[ -e /firstrun ]]; then
  source /scripts/first_run.sh
else
  source /scripts/normal_run.sh
fi

wait_for_postgres_and_run_post_start_action() {
  # Wait for postgres to finish starting up first.
#  while [[ ! -e /run/postgresql/9.3-main.pid ]] ; do
#      inotifywait -q -e create /run/postgresql/ >> /dev/null
#  done

  #wait a max of 5 minutes for postgres to startup.
  n=0
  until [ $n -ge 30 ]
  do
    su postgres -c "psql -t  -c \"select pg_postmaster_start_time()\" postgres" && break
    n=$[$n+1]
    sleep 10
  done

  post_start_action
}

pre_start_action

wait_for_postgres_and_run_post_start_action &

# Start PostgreSQL
echo "Starting PostgreSQL..."
setuser postgres /usr/lib/postgresql/9.3/bin/postgres -D /etc/postgresql/9.3/main