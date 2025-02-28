# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# ActiveMQ Artemis

FROM adoptopenjdk:11-jre-hotspot
LABEL maintainer="Apache ActiveMQ Team"
LABEL org.opencontainers.image.source https://github.com/sixflags/activemq-artemis-arm
# Make sure pipes are considered to determine success, see: https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV ARTEMIS_VERSION 2.17.0
ENV ARTEMIS_DIST_FILE_NAME apache-artemis-$ARTEMIS_VERSION-bin.tar.gz
ENV ARTEMIS_TMPDIR /tmp
ENV ARTEMIS_HOME /opt/activemq-artemis
ENV ARTEMIS_USER artemis
ENV ARTEMIS_PASSWORD artemis
ENV ANONYMOUS_LOGIN false
ENV EXTRA_ARGS --http-host 0.0.0.0 --relax-jolokia

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.12
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates dirmngr gnupg wget; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

# Install artemis and add user and group for artemis
RUN curl "https://mirrors.hostingromania.ro/apache.org/activemq/activemq-artemis/$ARTEMIS_VERSION/$ARTEMIS_DIST_FILE_NAME" --output "$ARTEMIS_TMPDIR/$ARTEMIS_DIST_FILE_NAME" && \
	mkdir $ARTEMIS_HOME && \
	tar zxf $ARTEMIS_TMPDIR/$ARTEMIS_DIST_FILE_NAME --directory $ARTEMIS_HOME --strip 1 && \
	groupadd -g 1000 -r artemis && useradd -r -u 1000 -g artemis artemis && \
	apt-get -qq -o=Dpkg::Use-Pty=0 update && \
	apt-get -qq -o=Dpkg::Use-Pty=0 install -y libaio1 && \
	rm -rf /var/lib/apt/lists/* && \
	chown -R artemis.artemis $ARTEMIS_HOME && \
	mkdir /var/lib/artemis-instance && chown -R artemis.artemis /var/lib/artemis-instance

COPY ./docker-run.sh /opt

RUN chmod +x /opt/docker-run.sh

# Expose some outstanding folders
VOLUME ["/var/lib/artemis-instance/etc-overrides", "/var/lib/artemis-instance/data"]
WORKDIR /var/lib/artemis-instance

# Web Server
EXPOSE 8161 \
# JMX Exporter
    9404 \
# Port for CORE,MQTT,AMQP,HORNETQ,STOMP,OPENWIRE
    61616 \
# Port for HORNETQ,STOMP
    5445 \
# Port for AMQP
    5672 \
# Port for MQTT
    1883 \
#Port for STOMP
    61613
	
ENTRYPOINT ["/opt/docker-run.sh"]
CMD ["run"]