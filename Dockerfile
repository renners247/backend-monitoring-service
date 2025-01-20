FROM ubuntu:22.04 AS base

# Install base dependencies for all services
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget curl jq netcat unzip gnupg software-properties-common

# Elasticsearch Service
FROM docker.elastic.co/elasticsearch/elasticsearch:7.10.0

# Set discovery type to single-node for standalone instance
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group
RUN echo "discovery.type=single-node" >> /etc/elasticsearch/elasticsearch.yml

# Configure volume mount for data persistence
VOLUME ["monitor-elasticsearch"]

# Expose port 9200
EXPOSE 9200

# Logstash Service
FROM docker.elastic.co/logstash/logstash:7.10.0

# Copy Logstash configuration file
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group
COPY logstash.conf /usr/share/logstash/pipeline/logstash.conf

# Set Java heap memory options
ENV LS_JAVA_OPTS="-Xmx256m -Xms256m"

# Restart Logstash on container changes
COPY --from=base /usr/sbin/cron /usr/sbin/cron
RUN echo "* * * * * /sbin/restart logstash" >> /etc/crontab

# Expose port 9600 (mapped to 6000 in the YAML config)
EXPOSE 9600
EXPOSE 6000

# Define dependency on Elasticsearch service
DEPENDS_ON elasticsearch

# Kibana Service
FROM docker.elastic.co/kibana/kibana:7.10.0

# Copy base dependencies
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group

# Set Elasticsearch host in Kibana configuration
ENV ELASTICSEARCH_HOSTS=http://elasticsearch:9200

# Expose port 5601
EXPOSE 5601

# Define dependency on Elasticsearch service
DEPENDS_ON elasticsearch

# Focalboard Service
FROM mattermost/focalboard:latest

# Copy base dependencies
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group

# Set Focalboard database environment variables
ENV FOCALBOARD_DATABASE_TYPE=sql
ENV FOCALBOARD_DATABASE_HOST=database
ENV FOCALBOARD_DATABASE_PORT=3306
ENV FOCALBOARD_DATABASE_NAME=focalboard
ENV FOCALBOARD_DATABASE_USERNAME=${DB_USERNAME}
ENV FOCALBOARD_DATABASE_PASSWORD=${DB_PASSWORD}

# Define dependency on database service
DEPENDS_ON database

# Configure volume mount for data persistence
VOLUME ["monitor-focalboard"]

# Expose port 8000 (mapped to 9900 in the YAML config)
EXPOSE 8000

# Database Service
FROM mysql/mysql-server:8.0

# Copy base dependencies
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group

# Set environment variables for database configuration
ENV MYSQL_ROOT_PASSWORD=${DB_PASSWORD}
ENV MYSQL_ROOT_HOST="%"
ENV MYSQL_DATABASE=${DB_DATABASE}
ENV MYSQL_USER=${DB_USERNAME}
ENV MYSQL_PASSWORD=${DB_PASSWORD}
ENV MYSQL_ALLOW_EMPTY_PASSWORD=1
ENV UPLOAD_MAX_SIZE=100M
ENV MEMORY_LIMIT=256M
ENV UPLOAD_LIMIT=100M

# Configure volume mount for data persistence
VOLUME ["monitor-mysql"]

# Expose port 3307 (mapped to a custom port in the YAML config)
EXPOSE 3307

# Define healthcheck for the database service
HEALTHCHECK CMD ["mysqladmin", "ping", "-p${DB_PASSWORD}"]
HEALTHCHECK RETRIES 3
HEALTHCHECK TIMEOUT 5s

# Define the network for all services
NETWORK monitor