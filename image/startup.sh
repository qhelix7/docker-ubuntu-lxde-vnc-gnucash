#!/bin/bash

mkdir -p /var/run/sshd

if [ -n "$VNC_USER" ]; then
    HOME=/home/${VNC_USER}
    if id "${VNC_USER}" >/dev/null 2>&1; then
        # user exists; make a home directory if it does not exist
        if [ ! -d "${HOME}" ]; then
            mkhomedir_helper ${VNC_USER}
        fi
    else
        adduser ${VNC_USER}
    fi
else
    VNC_USER=root
    HOME=/root
    chown -R root:root ${HOME}
fi

if [ -z "$VNC_GROUP" ]; then
    VNC_GROUP=VNC_USER
fi

# Need to create this directory to make settings available for some apps
mkdir -p ${HOME}/.config/dconf

mkdir -p ${HOME}/.config/pcmanfm/LXDE/
cp /usr/share/doro-lxde-wallpapers/desktop-items-0.conf ${HOME}/.config/pcmanfm/LXDE/
chown -R ${VNC_USER}:${VNC_GROUP} ${HOME}/.config

# Fix up supervisor confs:
if [ -n "$VNC_PASSWORD" ]; then
    echo -n "$VNC_PASSWORD" > ${HOME}/.password1
    x11vnc -storepasswd $(cat ${HOME}/.password1) ${HOME}/.password2
    chown ${VNC_USER}:${VNC_GROUP} ${HOME}/.password*
    chmod 400 ${HOME}/.password*
    sed -i "s~^command=x11vnc.*~& -rfbauth ${HOME}\/.password2~" /etc/supervisor/conf.d/supervisord.conf
    export VNC_PASSWORD=
fi

sed -i "s~\(^directory=/root\).*$~directory=${HOME}~" /etc/supervisor/conf.d/supervisord.conf
sed -i "s~\(^user=\).*$~\1${VNC_USER}~" /etc/supervisor/conf.d/supervisord.conf
sed -i "s~\(^environment=.*HOME=\"\)\([^\"]*\)~\1${HOME}~" /etc/supervisor/conf.d/supervisord.conf
sed -i "s~\(^environment=.*USER=\"\)\([^\"]*\)~\1${VNC_USER}~" /etc/supervisor/conf.d/supervisord.conf

if [ -n "$VNC_RES" ]; then
    # set resolution
    sed -i "s~\(command=.*\) [0-9]*x[0-9]*x[0-9]*~\1 ${VNC_RES}~" /etc/supervisor/conf.d/xvfb.conf
fi

cd /usr/lib/web && ./run.py > /var/log/web.log 2>&1 &
nginx -c /etc/nginx/nginx.conf
exec /bin/tini -- /usr/bin/supervisord -n
