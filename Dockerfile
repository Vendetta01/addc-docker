FROM npodewitz/confd:latest

LABEL de.podewitz.addc.description="Dockerized version of samba4 active directory domain controller"
LABEL de.podewitz.addc.version=0.1
LABEL de.podewitz.addc.maintainer="Nils Podewitz <nils.podewitz@googlemail.com>"




RUN apk --no-cache --update upgrade && \
    apk --no-cache --update add \
        bash \
	samba-dc \
	supervisor \
	vim \
	&& \
    rm -rf /etc/samba/* && \
    rm -rf /var/cache/samba/* && \
    rm -rf /var/lib/samba/* && \
    rm -rf /var/lock/samba/* && \
    rm -rf /etc/krb5.conf


COPY scripts/* /usr/bin/
COPY etc/ /etc/


EXPOSE 53 \
       88 \
       123/udp \
       135/tcp \
       137/udp \
       138/udp \
       139/tcp \
       389 \
       445/tcp \
       464 \
       636/tcp \
       3268/tcp \
       3269/tcp

VOLUME ["/var/lib/samba"]

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["samba-addc"]


