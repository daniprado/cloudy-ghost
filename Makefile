# Thanks to https://github.com/gomex/terraform-aws-consul/blob/master/Makefile

cnf ?= .envrc
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))
GIT_COMMIT=$(shell git log -1 --format=%h)

.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

tf-init: ## Run terraform init to download all necessary plugins
	docker run --rm -v $$PWD:/app -w /app/ -e ARM_ACCESS_KEY=$$ARM_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) hashicorp/terraform:$(TERRAFORM_VERSION) init -upgrade=true

tf-plan: ## Exec a terraform plan and puts it on a file called tfplan
	docker run --rm -v $$PWD:/app -w /app/ -e ARM_ACCESS_KEY=$$ARM_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) hashicorp/terraform:$(TERRAFORM_VERSION) plan -out=tfplan

tf-apply: ## Uses tfplan to apply the changes on Azure.
	docker run --rm -v $$PWD:/app -w /app/ -e ARM_ACCESS_KEY=$$ARM_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) hashicorp/terraform:$(TERRAFORM_VERSION) apply -auto-approve

tf-destroy: ## Destroy all resources created by the terraform file in this repo.
	docker run --rm -v $$PWD:/app -w /app/ -e ARM_ACCESS_KEY=$$ARM_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) hashicorp/terraform:$(TERRAFORM_VERSION) destroy -auto-approve

tf-sh: ## terraform console
	docker run -it --rm -v $$PWD:/app -w /app/ -e ARM_ACCESS_KEY=$$ARM_ACCESS_KEY -e TF_VAR_APP_VERSION=$(GIT_COMMIT) --entrypoint "" hashicorp/terraform:$(TERRAFORM_VERSION) sh

