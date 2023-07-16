# Proyecto de Cloud Computing con Azure, AWS y GCP
# unt-cloud-computing
    *: Se genera al crear un nuevo sandbox

# Set up Azure

## Primero debes tener la CLI de Azure instalada (Se sugiere hacerlo en WSL):
 - curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

    -> Referencia: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt#option-1-install-with-one-command
## Verificar con:
 - az version

## Luego hacer el login con:
 - az login

 Abrirá un link en su navegador, copien el link en el navegador donde estén logeados en azure y seleccionen la cuenta

## Modifica variables:
 - Actualizar el valor por default de la variable 'resource-group-name' con el nuevo nombre del grupo de recursos*

# Set up AWS

## Primero debes tener la CLIv2 de AWS instalada (Se sugiere hacerlo en WSL):
 - curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
 - unzip awscliv2.zip
 - sudo ./aws/install

## Verificar con:
 - aws --version

## Luego configurar las credenciales con:
 - aws configure
    -> Actualizar el 'Access key ID' y el 'Secret access key' con los nuevos*
    -> zona colocar 'us-east-1' y format 'json'

# Set up GCP
## Luego configurar las credenciales:
 - Crear un archivo llamado 'SA_credentials.json' con el contenido del Service Account*

# Set up Alibaba Cloud
 - Exportar variables de entorno
    export ALICLOUD_ACCESS_KEY="<ALICLOUD_ACCESS_KEY>"
    export ALICLOUD_SECRET_KEY="<ALICLOUD_SECRET_KEY>"
# Listo, estás listo para desplegar la infraestructura

# Despliegue de Infraestructura
Ubicarse en la carpeta donde estén los recurso .tf que se deseen desplegar
En la carpeta de cada sesión deben ejecutar la siguiente lista de comandos:
 - terraform version
 - terraform init
 - terraform workspace new production
 - terraform fmt
 - terraform validate
 - terraform plan
 - terraform apply --auto-approve
 - terraform destroy --auto-aprove

#### NOTA: Solo pushear los archivos .tf y .sh (Igualmente todo está validado en el .gitignore)
