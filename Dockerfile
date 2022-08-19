FROM quay.io/rockylinux/rockylinux:8 as ondemand

ARG slurm_version=22.05.3-1

RUN dnf -y install https://yum.osc.edu/ondemand/2.0/ondemand-release-web-2.0-1.noarch.rpm \
  && dnf -y update \
  && dnf install -y \
  dnf-plugins-core \
  epel-release \
  && dnf config-manager --add-repo https://yum.deepsquare.run/yum.repo \
  && dnf config-manager --set-enabled powertools \
  && dnf -y module enable nodejs:12 ruby:2.7 \
  && dnf install -y \
  ondemand \
  mod_authnz_pam \
  mod_auth_openidc \
  slurm \
  sssd \
  xz \
  authselect \
  zsh \
  nvslurm-plugin-pyxis \
  slurm-${slurm_version}.el8.x86_64 \
  slurm-contribs-${slurm_version}.el8.x86_64 \
  slurm-libpmi-${slurm_version}.el8.x86_64 \
  slurm-pam_slurm-${slurm_version}.el8.x86_64 \
  pam_mkslurmuser \
  s3cmd \
  pmix2 \
  pmix3 \
  pmix4 \
  hwloc \
  hwloc-libs \
  hwloc-devel \
  screen \
  tmux \
  git \
  openssh-server \
  openssh-clients \
  openldap-clients \
  wget \
  vim \
  sudo \
  htop \
  procps \
  net-tools \
  bind-utils \
  iproute \
  netcat \
  rsync \
  nano \
  && dnf clean all && rm -rf /var/cache/dnf/*

# Munge & Slurm configurations
RUN mkdir -p /run/munge && chown munge:munge /run/munge \
  && mkdir -p /var/run/munge && chown munge:munge /var/run/munge \
  && mkdir -p /var/{spool,run}/{slurmd,slurmctl,slurmdb}/ \
  && mkdir -p /var/log/{slurm,slurmctl,slurmdb}/
ENV SLURM_CONF=/etc/slurm/slurm.conf

RUN sed -Ei 's|UMASK\t+[0-9]+|UMASK\t\t077|g' /etc/login.defs \
  && authselect select sssd --force \
  && authselect enable-feature with-sudo \
  && echo 'session     optional      pam_mkslurmuser.so' >> /etc/pam.d/system-auth \
  && echo 'session     optional      pam_mkhomedir.so skel=/etc/skel/ umask=0077' >> /etc/pam.d/system-auth \
  && echo 'session     optional      pam_mkslurmuser.so' >> /etc/pam.d/password-auth \
  && echo 'session     optional      pam_mkhomedir.so skel=/etc/skel/ umask=0077' >> /etc/pam.d/password-auth \
  && setcap cap_net_admin,cap_net_raw+p /usr/bin/ping \
  && echo 'umask 0027' >> /etc/profile

# Copy configuration files
RUN mkdir -p /etc/ood/config
RUN cp /opt/ood/nginx_stage/share/nginx_stage_example.yml            /etc/ood/config/nginx_stage.yml
RUN cp /opt/ood/ood-portal-generator/share/ood_portal_example.yml    /etc/ood/config/ood_portal.yml

# Make some misc directories & files
RUN mkdir -p /var/lib/ondemand-nginx/config/apps/{sys,dev,usr}
RUN touch /var/lib/ondemand-nginx/config/apps/sys/{dashboard,shell,myjobs}.conf

# Configura auth
RUN echo -e 'Defaults:apache !requiretty, !authenticate \n\
  Defaults:apache env_keep += "NGINX_STAGE_* OOD_*" \n\
  apache ALL=(ALL) NOPASSWD: /opt/ood/nginx_stage/sbin/nginx_stage' >/etc/sudoers.d/ood \
  && echo "LoadModule authnz_pam_module modules/mod_authnz_pam.so" > /etc/httpd/conf.modules.d/55-authnz_pam.conf \
  && chmod 640 /etc/shadow \
  && chgrp apache /etc/shadow \
  && cp /etc/pam.d/sshd /etc/pam.d/ood

# run the OOD executables to setup the env
RUN /opt/ood/ood-portal-generator/sbin/update_ood_portal
RUN /opt/ood/nginx_stage/sbin/update_nginx_stage
RUN /usr/libexec/httpd-ssl-gencerts

VOLUME [ "/secrets/munge", "/secrets/sssd", "/secrets/sshd" ]

COPY s6-rc.d/munge/ /etc/s6-overlay/s6-rc.d/munge/
COPY s6-rc.d/ssh/ /etc/s6-overlay/s6-rc.d/ssh/
COPY s6-rc.d/sss/ /etc/s6-overlay/s6-rc.d/sss/
COPY s6-rc.d/apache/ /etc/s6-overlay/s6-rc.d/apache/
COPY s6-rc.d/ood-update/ /etc/s6-overlay/s6-rc.d/ood-update/
RUN mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d/ \
  && touch /etc/s6-overlay/s6-rc.d/user/contents.d/ssh \
  /etc/s6-overlay/s6-rc.d/user/contents.d/munge \
  /etc/s6-overlay/s6-rc.d/user/contents.d/sss \
  /etc/s6-overlay/s6-rc.d/user/contents.d/apache \
  /etc/s6-overlay/s6-rc.d/user/contents.d/ood-update

ENV S6_OVERLAY_VERSION=3.1.1.2

RUN curl -fsSL https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz -o /tmp/s6-overlay-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
  && curl -fsSL https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz -o /tmp/s6-overlay-x86_64.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz \
  && rm -rf /tmp/*

EXPOSE 80/tcp 22/tcp

ENTRYPOINT [ "/init" ]

FROM ondemand as ondemand-dex

RUN dnf install -y \
  ondemand-dex \
  && dnf clean all

# run the OOD executables to setup the env
RUN /opt/ood/ood-portal-generator/sbin/update_ood_portal

COPY s6-rc.d/dex/ /etc/s6-overlay/s6-rc.d/dex/
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/dex

EXPOSE 5556/tcp
