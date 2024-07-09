#!/bin/bash
#Clonar el repositorio
sudo apt update
sudo apt upgrade -y
cd
git clone https://github.com/jemjaf/rafita.git
sudo apt install wget build-essential libncursesw5-dev libssl-dev \
libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev -y
# sudo apt install software-properties-common -y
# sudo add-apt-repository ppa:deadsnakes/ppa --yes
# sudo apt install python3.11 -y
cd /usr/src
sudo wget https://www.python.org/ftp/python/3.11.1/Python-3.11.1.tgz
sudo tar xzf Python-3.11.1.tgz
cd Python-3.11.1
sudo ./configure --enable-optimizations
# sudo make
# sudo make install
sudo make altinstall
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11
pip3.11 install --upgrade pip
sudo apt install libpq-dev -y
cd
cd rafita/
pip3.11 install -r requirements.txt

# sudo apt install -y python3 python3-pip postgresql-client
# sudo apt install -y postgresql-client

# Configurar la conexión a la base de datos en settings.py
cat >> ./rafita/settings.py <<EOF
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'rafita',
        'USER': 'postgres',
        'PASSWORD': '',
        'HOST': '172.17.1.4',
        'PORT': '5432',
    }
}
EOF