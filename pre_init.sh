#!/bin/bash

set -e

CURR_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENVIRONMENT_FILE="${CURR_PATH}/.envrc"

RANDNESS="$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 7 | head -n 1)"
sed "s/\${RANDNESS}/${RANDNESS}/g" ${ENVIRONMENT_FILE}.orig > ${ENVIRONMENT_FILE}

source ${ENVIRONMENT_FILE}

AZ_OUT="${CURR_PATH}/az_out"
mkdir -p ${AZ_OUT}

# -------------------------------------------------------------------------------------------------
# CICD (pre-existent?) components creation
# -------------------------------------------------------------------------------------------------
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

./init.sh

if [[ -d ${AZ_OUT} ]]; then
  rm -rf ${AZ_OUT}
fi

exit 0

