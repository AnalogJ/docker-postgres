FROM abevoelker/postgres
MAINTAINER Jason Kulatunga <jason@thesparktree.com>

# copy over postgresql configuration files with wal-e enabled by default
COPY ./pg_hba.conf     /etc/postgresql/$VERSION/main/
COPY ./postgresql.conf /etc/postgresql/$VERSION/main/

# Set default environment modes

# determines if the postgres server is configured as a master or a slave.
# this can be one of the following: ["master", "slave"]
ENV DOCKER_POSTGRES_MODE master

# determines if a wal-e database backup should be recovered before starting postgres.
# this can be one of the following: ["true", "false"]
ENV DOCKER_POSTGRES_RECOVER false #this can be one of the following: ["true", "false"]

# if DOCKER_POSTGRES_RECOVER is true, this value determines which backup is restored
# the latest, or a specific date. ['latest', eg. '2012-03-06 16:38:00']
ENV DOCKER_POSTGRES_RECOVER_FROM latest


# copy over startup script
COPY startup.sh /data/scripts/startup.sh
RUN chmod -R 755 /data/scripts/startup.sh

# run periodic full backups with cron + WAL-E, via runit
CMD ["/data/scripts/startup.sh"]

# Keep Postgres log, config and storage outside of union filesystem
VOLUME ["/var/log/postgresql", \
        "/var/log/supervisor", \
        "/etc/postgresql/9.3/main", \
        "/var/lib/postgresql/9.3/main"]

EXPOSE 5432