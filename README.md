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

## Primero debes tener la gcloud CLI de GCP instalada (Se sugiere hacerlo en WSL):
 - Seguir los pasos de la siguiente docu
 - https://cloud.google.com/sdk/docs/install?hl=es-419#linux

## Verificar inicializando:
 - gcloud init
    -> El link que provee llevarlo al navegador donde estés logueado con tu cuenta de google para realziar el despliegue

## Luego configurar las credenciales:
 - Actualizar el contenido del archivo 'SA_credentials.json' con el nuevo Service Account*
 - Actualizar el valor del 'project' en el archivo providers.tf con el id del nuevo proyecto*

# Listo, estás listo para desplegar la infraestructura

# Despliegue de Infraestructura
En la carpeta de cada sesión deben ejecutar la siguiente lista de comandos:
 - terraform version
 - terraform init
 - terraform fmt
 - terraform validate
 - terraform plan
 - terraform apply --auto-aprove
 - terraform destroy --auto-aprove

#### NOTA: Solo pushear los archivos .tf y .sh (Igualmente todo está validado en el .gitignore)
