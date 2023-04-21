# Deploy fips enabled keycloak on OCP
**Currently under construction**

## Synopsis
This provides an easy automated way to deploy fips enabled keycloak on OCP via the operator.

The automation will do the following:
- Create PostgreSQL Database
- Install keycloak instance with FIPS enabled


## Prerequistes

- Keycloak Operator installed via [OLM](https://www.keycloak.org/operator/installation)
- oc cli installed
- Logged into OC cluster via cli
- Requried permissions sets to create k8's objects in project
- keytool installed
- openssl installed

## Setup
Modify keycloak.yaml

| spec | Description |
| --- | --- |
| Route host | These must be unique so add unique id (generally just add project name)
| keycloak namespace | The namespace to deploy keycloak app.
| keycloak db url | Need to match the database route we will install before running keycloak.yml
| keycloak hostname | match Route host name

## Usage
| Description | Command |
| ----------- | ------- |
Install PostgreSQL | `oc -n <PROJECT NAME HERE> new-app -e POSTGRESQL_USER=admin -e POSTGRESQL_PASSWORD=password -e POSTGRESQL_DATABASE=keycloak --image-stream="openshift/postgresql:13-el7"`   
Install Keycloak  | `oc process -f keycloak.yaml -p NAMESPACE=<PROJECT NAME HERE> \| oc create -f -`
Remove all of setup | `oc delete keycloaks,routes,services,deployments -n <PROJECT NAME HERE> --all`