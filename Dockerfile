FROM rockylinux/rockylinux:8

ENV COBBLER_RPM cobbler-3.3.3-1.el8.noarch.rpm
ENV DATA_VOLUMES "/var/lib/cobbler /var/www/cobbler /var/lib/dhcpd"

COPY $COBBLER_RPM /$COBBLER_RPM
RUN set -ex \
  && dnf install -y epel-release \
  && dnf install -y /$COBBLER_RPM \
  && dnf install -y httpd dhcp-server pykickstart yum-utils debmirror git rsync-daemon \
          ipxe-bootimgs shim grub2-efi-x64-modules python3-mod_wsgi python3-pyyaml \
          openssl procps-ng rsyslog \
  && dnf clean all \
  # fix debian repo support
  && sed -i "s/^@dists=/# @dists=/g" /etc/debmirror.conf \
  && sed -i "s/^@arches=/# @arches=/g" /etc/debmirror.conf \
  # backup data volumes
  && for v in $DATA_VOLUMES; do mv $v ${v}.save; done

# DHCP Server
EXPOSE 67
# TFTP
EXPOSE 69
# Rsync
EXPOSE 873
# Web
EXPOSE 80
# Cobbler
EXPOSE 25151

VOLUME ["/var/lib/cobbler", "/var/www/cobbler", "/var/lib/dhcpd"]

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
