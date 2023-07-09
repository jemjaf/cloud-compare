#!/bin/bash
sudo apt update
sudo apt upgrade -y
#Testeo
echo "wasd" > /opt/test.txt


#Clonar el repositorio
cd /opt
git clone https://github.com/jeaneliasmanuel/rafita.git

#Instalar Python3
# sudo apt install wget build-essential libncursesw5-dev libssl-dev \
# libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev -y
# sudo apt install software-properties-common -y
# sudo add-apt-repository ppa:deadsnakes/ppa --yes
# sudo apt install python3.11 -y
# cd /usr/src
# sudo wget https://www.python.org/ftp/python/3.11.1/Python-3.11.1.tgz
# sudo tar xzf Python-3.11.1.tgz
# cd Python-3.11.1
# sudo ./configure --enable-optimizations
# # sudo make
# # sudo make install
# sudo make altinstall || echo "Test1" > test3.txt

#Error
cd /opt/rafita
#Instalar pip
sudo apt install python3-pip -y
pip3 install --upgrade pip
sudo apt install libpq-dev -y

#Inicia el deployment
cd /opt/rafita
#Instalar requirements
pip3 install -r requirements.txt

# sudo apt install -y python3 python3-pip postgresql-client
sudo apt install -y postgresql-client

# Configurar la conexión a la base de datos en settings.py

cat >> ./rafita/settings.py <<EOF

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'rafita',
        'USER': 'postgres',
        'PASSWORD': 'cOJRLC2Wtr4x',
        'HOST': '${private_ip}',
        'PORT': '5432',
    }
}
EOF

# # Iniciar la aplicación Django
# python3.11 ./manage.py runserver 0.0.0.0:8000
python3 manage.py makemigrations
python3 manage.py migrate
python3 manage.py createsu
python3 manage.py shell < comandos.py
python3 manage.py runserver 0.0.0.0:8000