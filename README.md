# Azure deployment of Ghost CMS.

The current repository contains my deployment PoC of [[https://ghost.org|Ghost]] application, trying to fulfill the following requirements:

* The application should be able to scale depending on the load.
* There should be no obvious security flaws. Also including RBAC policies.
* The application must return consistent results across sessions.
* The implementation should be built in a resilient manner. Including:
  * High availability.
  * Disaster recovery in case of region failure.
* Observability must be taken into account when implementing the solution. Including:
  * Production environment.
  * Development environments.
* The deployment of the application and environment should be automated. Including:
  * Production environment versions & infrastructure.
  * Development environments for 5 development teams.
  * No downtime on Production environment due to new versions being deployed.
* Extend application's functionality via a serverless function able to remove data from the system.

## Getting Started

### Dependencies

- Docker
- Make or Terraform CLI

#### Executing

- The first step is filling the MS Azure credentials variables (ARM_*) inside the `.envrc.orig` file.
- Next, the execution of `pre_init.sh` will generate a CICD resource group containing the basic components needed (an storage account and a container registry) and finalize setting up the Terraform environment (by filling *.orig files with appropriate values and copying their content to the "non-orig" final files).
- At this point it is time to start executing Terraform commands from the command line. We have two options:
  - Using Make (via the `Makefile` present): we would start by `make tf-init`, followed by `make tf-apply` to deploy all components (type `make help` for a list and explanation on all commands inside `Makefile`).
  - Using Terraform CLI: we would start by loading the environment variables contained in `.envrc` file by executing `source .envrc`. Once this is done the sequence (in the same command line session) should be `terraform init` followed by `terraform apply -auto-approve` to deploy all components.

As an alternative to step 2, we can avoid generating the "pre_init" components in our Azure subscription by editing further `.envrc.orig` and provide appropriate values for CICD_* variables. After the editing we need to rename the file to `.envrc` and execute `init.sh` script instead of the "pre_init" one.

## Author

Daniel Prado dpradom@argallar.com
