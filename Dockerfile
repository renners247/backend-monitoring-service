FROM ubuntu:22.04 AS base

# Install base dependencies for all services
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget curl jq netcat unzip gnupg software-properties-common

# Expose port 9200
EXPOSE 9200

COPY logstash.conf /usr/share/logstash/pipeline/logstash.conf

# Restart Logstash on container changes
COPY --from=base /usr/sbin/cron /usr/sbin/cron
RUN echo "* * * * * /sbin/restart logstash" >> /etc/crontab

# Expose port 9600 (mapped to 6000 in the YAML config)
EXPOSE 9600
EXPOSE 6000

# Expose port 5601
EXPOSE 5601

# Expose port 8000 (mapped to 9900 in the YAML config)
EXPOSE 8000

# Expose port 3307 (mapped to a custom port in the YAML config)
EXPOSE 3307