#!/usr/bin/env bash

if [ -f ~/.homestead-features/wsl_user_name ]; then
    WSL_USER_NAME="$(cat ~/.homestead-features/wsl_user_name)"
    WSL_USER_GROUP="$(cat ~/.homestead-features/wsl_user_group)"
else
    WSL_USER_NAME=vagrant
    WSL_USER_GROUP=vagrant
fi

export DEBIAN_FRONTEND=noninteractive

# determine the postgres major version
ver=$(pg_config --version | tr -d ' ' | cut -d'.' -f1 | rev | cut -c1,2 | rev)

if [ -f /home/$WSL_USER_NAME/.homestead-features/postgres-pghashlib-${ver} ]
then
    echo "postgres-pghashlib for version $ver already installed."
    exit 0
fi



touch /home/$WSL_USER_NAME/.homestead-features/postgres-pghashlib-${ver}
chown -Rf $WSL_USER_NAME:$WSL_USER_GROUP /home/$WSL_USER_NAME/.homestead-features

# Install dependencies
apt-get update
apt-get install -y python3-docutils

# build
cd /usr/src &&
sudo git clone https://github.com/bgdevlab/pghashlib.git pghashlib-${ver} &&
cd pghashlib-${ver}/ &&
if [ -e "$(find $(pg_config --includedir) -name 'varatt.h')" ]; then
    # postgres 16+ fails for phhashlib
    # build failure on postgres16 - https://stackoverflow.com/questions/77617997/how-to-set-varsize-and-set-varsize-in-postgresql-16
    # append after match #include <fmgr.h> - src/pghashlib.h
    line=$(grep -n '#include <fmgr.h>' src/pghashlib.h | cut -d: -f1)
    sudo sed -i "${line}a #include <varatt.h>\n" src/pghashlib.h
fi &&
sudo make || true
sudo make install || true

# install extension
sudo su - postgres -c "psql -U postgres -c 'CREATE EXTENSION hashlib;'"
sudo su - postgres -c "psql -U postgres -c \"select encode(hash128_string('abcdefg', 'murmur3'), 'hex');\""

# package the build extension
tar -czf ubuntu-20-postgresql-$ver.hashlib.tgz $(find /usr/share/doc/postgresql-doc-$ver/  /usr/lib/postgresql/$ver/lib/bitcode/hashlib /usr/lib/postgresql/$ver/lib/hashlib.so /usr/share/postgresql/$ver/extension/hash*)
