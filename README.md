# Azure deployment of Ghost Application.

## Intended scope
The current repository contains my deployment PoC of [Ghost](https://ghost.org) application, trying to fulfil the following requirements:

- [ ] The application should be able to scale depending on the load.
- [ ] There should be no obvious security flaws. Including RBAC policies.
- [ ] The application must return consistent results across sessions.
- [ ] The implementation should be built in a resilient manner. Including:
  - [ ] High availability.
  - [ ] Disaster recovery in case of region failure.
- [ ] Observability must be taken into account when implementing the solution. Including:
  - [ ] Production environment.
  - [ ] Development environments.
- [ ] The deployment of the application and environment should be automated. Including:
  - [ ] Production environment versions & infrastructure.
  - [ ] Development environments for 5 development teams.
  - [ ] No downtime on the Production environment due to new versions being deployed.
- [ ] Extend application's functionality via a serverless function able to remove data from the system.
- [ ] Take all the decisions based on cost, maintainability and extensibility optimization.

## Getting started

### Dependencies

- Docker
- GNU Make or Terraform CLI

#### Executing

1. The first step is filling the MS Azure credentials variables (*ARM_&ast;*) inside the `.envrc.orig` file.
2. Next, we generate a CICD resource group containing the basic components needed (a storage account and a container registry) and finalize setting up the Terraform environment (by filling *&ast;.orig* files with appropriate values and copying their content to the "non-orig" final files). Executing in our shell:
   ```
   ./pre_init.sh
   ```

3. At this point we load the environment variables contained in `.envrc` file into our command line session and deploy all components using Terraform. We have two options:
   - Using Make (via the `Makefile` present).
     ```
     make tf-init
     make tf-apply
     ```
     (type `make help` for a list and explanation on all commands inside `Makefile`)
   - Using Terraform CLI.
     ```
     source .envrc
     terraform init
     terraform apply -auto-approve
     ```

As an **alternative to step 2**, we can avoid generating the "pre_init" components in our Azure subscription by editing further `.envrc.orig` and providing appropriate values for *CICD_&ast;* variables (names for existing components in our subscription). Later:
```
cp .envrc.orig .envrc
./init.sh
```

## Code considerations

- The current code in the repository represents a partial solution for the full problem (see below).
- The Terraform code is structured in modules to improve readability, extensibility and reuse inside the project itself. There is no intention of making these modules suitable for reuse outside of the current context.
- All the code tries to be self-documented including explanations for non-standard decisions also tagging pending improvements and shortcuts taken:
  - `TODO` shows pending tasks not solved due to the PoC nature of the code.
  - `FIXME` shows a shortcut decision is taken or something that should not be included in production-ready code.

## Analysis and development processes

The approach followed to solve the requirements has been iterative. Keeping the final goals as a vision, but solving specific parts of the system in every cycle. All this uses a top-down direction in terms of relevance, amount of requisites solved and future re-work caused.

### Initial thoughts

Ghost application is not a complex piece of software. It is possible to make it run inside a docker container with a couple of common integrations (SQL database, file storage,...). Taking into account the costs and maintainability requirements, it looks like a PaaS-when-possible approach combined with containerized software package is the way to go. This will mean using an Azure App Service for containers as the central component in the project.

### Iteration 0 - Pre existent infrastructure

The starting point is getting access to a Microsoft subscription.
While basic, the organization needs some infrastructure already in place when starting the project:
- An `Storage Account` able to contain Terraform's status is mandatory to build something bigger than a one-person-show project.
- As development teams will work on the project's code, a `Container Registry` is also needed. For this PoC, I decided to just download the latest version of the [community docker image](https://hub.docker.com/_/ghost/) and push it to the ACR. This will be the version deployed to the infrastructure.
- Both components should be inside a `Resource Group`. I would expect these components to be of wider use inside the organization, so I decided to name them as part of the "CICD" project.

As this iteration is not part of the project itself, I decided to implement it as shell scripts (`pre_init.sh` & `init.sh`) that also provide the needed setup for the Terraform environment being used in the next iterations (i.e. the SAS key to store Terraform's state file in the cloud).

Once this pre-work is done, we are ready to start the project.

### Iteration 1 - Make it run!

Making Ghost application run inside an `App Service for containers` is the next step. This requires creating some of the key components of the infrastructure and solving their connectivity needs:
- A Linux `App Service Plan` provides the runtime environment for the mentioned *App Service*.
- A `Database for MySQL` server provides the persistence layer for the application. Inside this server, a *database* is created and a specific user to operate it from the application. In terms of security, the *App Service* needs network access to the server and the created user/password need to be accessible in a secure way.
- A `Keyvault` provides storage and access to the secret credentials to access the database. This means that the *App Service* will access it during boot time, so an access policy needs to be applied.
- To provide observability (and alerting capabilities): the *App Service* is registered to a specific `Application Insights` component, while the *database server* and the *service plan* send their metrics to a `Log Analytics Workspace`. These are not mandatory to make the application run, but introduce the importance of monitoring in the whole system from the start.
- Finally, all these components are packaged inside a `Resource Group` that contains them and will become in coming iterations the "unit of deployment" for the application (meaning that next iterations will modify and replicate this resource group to achieve most of the pending requirements).

It is worth mentioning that all these components are deployed inside the same Azure region (from now on "primary location").

There is one important component missing in this iteration, which is the `Storage Account` that should serve as persistence for files uploaded into the application. I decided to keep it out of the PoC, as it requires modifying the docker image to be used (please check the related **FIXME** tag inside the code for more information).

The result at this point is a fully running application, next to its observability and monitoring tools.

### Iteration 2 - High availability

Due to the chosen components in the previous iteration, some of the resilience and cross-region disaster recovery requirements are solved directly by Azure (i.e. *Keyvault* access). But not all of them, so this iteration requires to re-structure the infrastructure and creating some more components:
- As a starting point, both *Keyvault* and *Log Analytics workspace* have cross-region capabilities in place making them *global* services for this project. A specific "global" `Resource Group` is created to allocate them. As they are still bound to the regions given on creation time, I decide not to change its naming convention (they are inside the "global" *resource group*, but the location portion of their name keeps unchanged).
- *Database for MySQL* is a completely different topic as it cannot be cross-region. It is necessary to look for an alternative, and I find the new (still in preview) `Flexible Server` component the best option. This solution is somehow in between PaaS and IaaS approaches, taking advantage of the *Availability Zones* concept provided to *Virtual Machines* in Azure (when choosing *Zone-redundant HA*) while keeping other advantages of *Database for MySQL* (i.e. backups). The approach would be creating this new component and its requirements (*VNet*, *NSG*,...) inside the "global" resource group. However, this adds a cost and complexity that I consider beyond the current PoC (please check the **TODO** tag in the code).
- The requirement of scalability based on load, makes it necessary to use a `Monitor Autoscale` policy so the number of instances running increases/decreases automatically based on a metric. I decided to make it check the length of the HTTP Queue on the *Service Plan*.
- On the other hand, making the application resilient to regional disasters requires creating a new deployment on a secondary region. The *paired regions* concept from Azure is important here and makes the pair of our "primary location" the optimal choice. This means creating replicas of the four remaining components in the "unity of deployment" I mentioned in the previous iteration: `Resource group`, `App Service Plan`, `App Service`, `Application Insights`. It is also important to mention the need of sending telemetry data from the new *Service Plan* to the existing *Log Analytics Workspace*.
- Last but not least, having two running instances must be orchestrated by some sort of load balancer (in this case just to send requests to the secondary instance only when the primary is not responding). The chosen component is a `Front Door`. This service is also deployed in the "global" resource group (it is the only component that is truly global).

At this point, the running application should be able to recover from regional disasters in its primary region with minimal to no downtime. It should also be able to scale to handle way more load than required.

**The current code in the repository represents the end of this iteration.**

### Iteration 3 - CICD

Once the infrastructure is ready to contain the initial version of the application, it is time to define the releasing process. The requirements mention 5 development teams, which are quite a lot for such a small infrastructure. This makes me think of a disposable environments approach as a good choice:
- The code repository of the application is allocated in Github and `Github actions` the execution environment for the pipelines.
- Leaving alone the *Azure Subscription* that already contains all the infrastructure from previous iterations (now labelled "PROD"), we need a second `Azure Subscription` ("Non-PROD") which will contain the environments to be created. Most probably the CICD *resource group* should also be allocated here, but I don't have a strong opinion about that.
- The environment creation (both infrastructure and deployment of a code version) is triggered by pushing a branch to the code repository. The initial push creates the infrastructure while building the docker image that is immediately deployed to it. Later pushes to the same branch will build/upgrade the docker image alone.
- This kind of environment contains the same components/setup built on iteration 1 (`Resource group`, `Keyvault`, `App Service Plan`, `App Service`,...) making it complete and independent from the rest of the infrastructure.
- Once the branch is merged to the master one, it is marked to be removed from the server. The same applies to the disposable environment created. Later, an automated task (i.e. cron triggered `Function App`) will remove the branch and destroy the environment.
- The same merge to master triggers the Production deployment of a new version of the application. Using a `Deployment Slot` component (in each region) we accomplish a blue-green deployment with zero downtime and immediate rollback capabilities. These new components have to be added to the appropriate *resource groups*.

This defines the releasing process for the application (with zero downtime) and solves the needs of testing environments for developers.

### Iteration 4 - Backoffice

The missing requirements at this point are the serverless function to remove data from the system (solved by an HTTP triggered `Function App`) and defining RBAC policies for the different teams involved (i.e. giving *Contributor* access to the developers in the "non-PROD" *subscription* only).

An initial (**untested**) version of the *Function App* has been included under `src/backofficer-func` path. This folder contains all needed files to create a Docker image deployable into a Function App for Containers component.  We should be able to execute the endpoint `/clean_all` of the App to remove all the posts in the system (we need a function key to authenticate our request).<br/>
The function's code:
1. Reads from the config parameters (present in the component) the environment variables it needs to be executed (including an API Key for the Ghost application, that should be stored into our *Keyvault*). 
1. Gets all the posts in the system (via Ghost's admin API) and delete them one by one. This is based on two assumptions:
   - The admin API does not accept to remove all in a single call (I understood so from the documentation, but I did not test it...).
   - The total amount of posts is not too big (some number in the hundreds will never take too long to delete).

## Author

Daniel Prado dpradom@argallar.com

