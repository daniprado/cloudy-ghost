#!/bin/bash

set -e

CURR_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source ${CURR_PATH}/.envrc

AZ_OUT="${CURR_PATH}/az_out"
mkdir -p ${AZ_OUT}

# Storage Account "wait" workaround: https://github.com/Azure/azure-cli/issues/1528#issuecomment-720750332
docker run --rm -v ${AZ_OUT}:/out mcr.microsoft.com/azure-cli /bin/bash -c "\
  az login --service-principal --tenant ${ARM_TENANT_ID} --username ${ARM_CLIENT_ID} \
      --password ${ARM_CLIENT_SECRET} && \
    echo 'Azure logged in.' && \
  az account set --subscription ${ARM_SUBSCRIPTION_ID} && \
    echo 'Selected subscription.' && \
  az group create --location ${CICD_LOCATION} --name ${CICD_RESOURCE_GROUP} && \
    echo 'Resource Group created.' && \
  az storage account create --resource-group ${CICD_RESOURCE_GROUP} --name ${CICD_STORAGE_ACCOUNT} \
      --sku Standard_LRS --access-tier Hot --kind BlobStorage --encryption-services blob \
      --allow-blob-public-access true && \
    echo 'Storage account requested.' && \
  while true; do
    PROVISIONED=\$(az storage account show --name ${CICD_STORAGE_ACCOUNT} \
                    --query [provisioningState] --output tsv)
    [[ \$PROVISIONED == 'Succeeded' ]] && break
  done && \
    echo 'Storage account created.' && \
  az storage container create --name ${CICD_TFSTATE_BLOB} --account-name ${CICD_STORAGE_ACCOUNT} \
      --auth-mode login && \
    echo 'Container created.' && \
  az storage account keys list --resource-group ${CICD_RESOURCE_GROUP} \
      --account-name ${CICD_STORAGE_ACCOUNT} --query '[0].value' -o tsv > /out/sto_key && \
  az acr create --name ${CICD_CONTAINER_REGISTRY} --resource-group ${CICD_RESOURCE_GROUP} \
      --sku Basic --admin-enabled true && \
    echo 'Container registry created.' && \
  az acr credential show --name ${CICD_CONTAINER_REGISTRY} --query username -o tsv \
      > /out/acr_usr && \
  az acr credential show --name ${CICD_CONTAINER_REGISTRY} --query passwords[0].value -o tsv \
      > /out/acr_pwd && \
  az logout && \
    echo 'Azure logged out.'"

echo "export ARM_ACCESS_KEY=$(cat ${AZ_OUT}/sto_key)" >> ${CURR_PATH}/.envrc
echo "Added Storage account access key to local vars."

envsubst < ${CURR_PATH}/terraform.tfvars.orig > ${CURR_PATH}/terraform.tfvars
echo "Updated backend parameters in Terraform source."

ACR_USR="$(cat ${AZ_OUT}/acr_usr)"
ACR_PWD="$(cat ${AZ_OUT}/acr_pwd)"
ACR_URL="${CICD_CONTAINER_REGISTRY}.azurecr.io"
docker login ${ACR_URL} --username ${ACR_USR} --password-stdin <<EOF
${ACR_PWD}
EOF
echo "Docker logged in."

GHOST_IMAGE_ORIG="ghost:${GHOST_VERSION}"
GHOST_IMAGE_DEST="${ACR_URL}/${GHOST_IMAGE_ORIG}"
docker pull ${GHOST_IMAGE_ORIG}
docker tag  ${GHOST_IMAGE_ORIG} ${GHOST_IMAGE_DEST}
docker push ${GHOST_IMAGE_DEST}
echo "Ghost image pushed to registry."

docker logout ${ACR_URL}
echo "Docker logged out."

rm -rf ${AZ_OUT}

exit 0

