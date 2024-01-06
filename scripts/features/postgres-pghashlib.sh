#!/usr/bin/env bash

if [ -f ~/.homestead-features/wsl_user_name ]; then
    WSL_USER_NAME="$(cat ~/.homestead-features/wsl_user_name)"
    WSL_USER_GROUP="$(cat ~/.homestead-features/wsl_user_group)"
else
    WSL_USER_NAME=vagrant
    WSL_USER_GROUP=vagrant
fi

export DEBIAN_FRONTEND=noninteractive

if [ -f /home/$WSL_USER_NAME/.homestead-features/postgres-pghashlib ]
then
    echo "postgres-pghashlib already installed."
    exit 0
fi

touch /home/$WSL_USER_NAME/.homestead-features/postgres-pghashlib
chown -Rf $WSL_USER_NAME:$WSL_USER_GROUP /home/$WSL_USER_NAME/.homestead-features

# Install dependencies
apt-get update
apt-get install -y python3-docutils

# build
cd /usr/src &&
git clone https://github.com/bgdevlab/pghashlib.git &&
cd pghashlib/ &&
make
make install

# install extension
sudo su - postgres -c "psql -U postgres -c 'CREATE EXTENSION hashlib;'"
sudo su - postgres -c "psql -U postgres -c \"select encode(hash128_string('abcdefg', 'murmur3'), 'hex');\""

# package the build extension
tar -czf ubuntu-20-postgresql-15.hashlib.tgz $(find /usr/share/doc/postgresql-doc-15/  /usr/lib/postgresql/15/lib/bitcode/hashlib /usr/lib/postgresql/15/lib/hashlib.so /usr/share/postgresql/15/extension/hash*)
