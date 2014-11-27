FROM abevoelker/postgres
MAINTAINER Jason Kulatunga <jason@thesparktree.com>

ENV VERSION 9.3

# copy over postgresql configuration files with wal-e enabled by default
COPY ./pg_hba.conf     /etc/postgresql/$VERSION/main/
COPY ./postgresql.conf /etc/postgresql/$VERSION/main/

# Set default environment modes

# determines if the postgres server is configured as a leader or a follower.
# master nodes generate the backups and the logs (wal-e is running in archive mode)
# slave nodes can only consume logs, DEFAULT, this is so that if we forget to set the value we dont accidently clobber our backups
# this can be one of the following: ["leader", "follower"]
ENV DOCKER_POSTGRES_MODE follower

# determines if a wal-e database backup should be recovered before starting postgres.
# this can be one of the following: ["true", "false"]
ENV DOCKER_POSTGRES_RECOVER false #this can be one of the following: ["true", "false"]

# if DOCKER_POSTGRES_RECOVER is true, this value determines which backup is restored
# the latest, or a specific date. ['LATEST', eg. '2012-03-06 16:38:00']
ENV DOCKER_POSTGRES_RECOVER_FROM LATEST

# copy the wal-e crontab file
# Crontab that does a full backup daily at 2AM and deletes old backups (retaining 7 previous backups) at 3AM:
COPY ./cron/wal-e     /etc/cron.d/wal-e

# copy over startup script
COPY startup.sh /data/scripts/startup.sh
RUN chmod -R 755 /data/scripts/startup.sh

# run periodic full backups with cron + WAL-E, via runit
CMD ["/data/scripts/startup.sh"]
