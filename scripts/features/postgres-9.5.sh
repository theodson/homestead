#!/usr/bin/env bash

if [ -f ~/.homestead-features/wsl_user_name ]; then
    WSL_USER_NAME="$(cat ~/.homestead-features/wsl_user_name)"
    WSL_USER_GROUP="$(cat ~/.homestead-features/wsl_user_group)"
else
    WSL_USER_NAME=vagrant
    WSL_USER_GROUP=vagrant
fi

export DEBIAN_FRONTEND=noninteractive

if [ -f /home/$WSL_USER_NAME/.homestead-features/postgres-9.5 ]; then
    echo "postgres-9.5 already installed."
    exit 0
fi

touch /home/$WSL_USER_NAME/.homestead-features/postgres-9.5
chown -Rf $WSL_USER_NAME:$WSL_USER_GROUP /home/$WSL_USER_NAME/.homestead-features

#
ver=9.5
port=5432
cluster_name=main
postgresql_conf="/etc/postgresql/${ver}/${cluster_name}/postgresql.conf"
pg_hba_conf="/etc/postgresql/${ver}/${cluster_name}/pg_hba.conf"

#var/lib/postgresql='/var/lib/postgresql'
#postgresql/config='/etc/postgresql'

#
if apt list --installed 2>/dev/null | grep -q "postgresql-${ver}"; then
    echo "postgresql-${ver} already installed.. removing"
    sudo apt remove -y postgresql-client-$ver postgresql-$ver postgresql-contrib-$ver postgresql-server-dev-$ver
    sudo rm -rf /var/lib/postgresql/$ver/main
    sudo rm -rf /etc/postgresql/$ver/main
fi

# Install dependencies
apt-get update
apt-get install -y postgresql-client-$ver postgresql-$ver postgresql-contrib-$ver postgresql-server-dev-$ver

# initialise
echo "pg_lsclusters | grep -q '/$ver/${cluster_name}'"
if ! pg_lsclusters | grep -q "/$ver/${cluster_name}"; then
    echo -e "\n\nPostgresql ${ver} cluster missing... creating now"
    sudo su -l postgres -c "pg_createcluster $ver main -- -Atrust"
else
    echo "postgresql $ver cluster found ... skipping"
fi
sudo systemctl daemon-reload

# disable other postgresql instances
for other in $(systemctl list-units --all 'postgresql*' | sed 's/^ *//g' | grep '^postgresql[@-][[:digit:]]' | cut -d' ' -f1 | sed 's/.service//' | grep -v "@$ver"); do
    sudo systemctl stop $other
    sudo systemctl disable $other
done

# set port
# on debian mutliple versions of postgresql automatically get then next available port from 5432
sudo su -l postgres -c "echo port = '$port' >> ${postgresql_conf}"
# pg_wrapper - TODO FIGURE THIS OUT
# run('echo "* * {{postgres_version}} main:{{db_port}} *" | sudo tee -a /etc/postgresql-common/user_clusters');

# ### pghashlib
# Install dependencies
apt-get install -y python3-docutils postgresql-server-dev-$ver

# build extension for murmur3 hashing
# specific version of pg_config needs to be in path for correct make environment
export PATH=/usr/lib/postgresql/9.5/bin/:$PATH

[ -e /usr/src/pghashlib${ver} ] && rm -rf /usr/src/pghashlib${ver}

cd /usr/src &&
git clone https://github.com/bgdevlab/pghashlib.git pghashlib${ver} &&
cd pghashlib${ver} &&
make
make install

# install extension
sudo su - postgres -c "psql -U postgres -c 'CREATE EXTENSION hashlib;'"
sudo su - postgres -c "psql -U postgres -c \"select encode(hash128_string('abcdefg', 'murmur3'), 'hex');\""
# ### pghashlib


sudo systemctl daemon-reload
sudo systemctl enable postgresql@${ver}-main.service || true
sudo systemctl start postgresql@${ver}-main.service
