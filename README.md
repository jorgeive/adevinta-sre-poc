# SRE sample app


## Asumption
The goal of this POC is create an AWS stack with a simple helloworld application in an automated, resilient, scalable and repeatable way.
The POC is based on Kubernetes, the most commmonly used open-source container-orchestration system. It's prepared to support any kind of microservice architecture and therefore is completely scalable.
SCM tools used is GIT for code version control.
Terraform as a tool to create all the Amazon resources and the RDS PostgreSQL instance.
Github Actions as the CI/CD for both code and manifests.
NGINX Ingress expose our applications and is also used as a load balancer mechanism.

## Tools Used
Below you can find all the tools used for this POC:
* [kubectl](https://github.com/kubernetes/kubectl) : Interact with Kubernetes cluster.
* [terraform](https://github.com/hashicorp/terraform) : IAC tool that codifies APIs into declarative configuration files in order to interact with AWS.
* [helm](https://github.com/helm/helm): Deploy pre-configured Kubernetes resources.
* [docker](https://github.com/docker): Container technology.
* [kops](https://github.com/kubernetes/kops): Oficial Kubernetes project for managing Kubernetes Clusters.
* [jq](https://github.com/stedolan/jq): Lightweight and flexible command-line JSON processor.

## Deploy
Set up an IAM user account for terraform with the following permissions:
- AmazonRoute53FullAccess
- AmazonDynamoDBFullAccess
- AmazonRDSFullAccess
- IAMFullAccess

Create a S3 remote state backend to store and manage the state of Terraform (tf-state) and Kops state.
Once the infraestructure is completely deployed, push a commit in the master branch and GithubActions will build the application and apply the manifests.
A complete guide of all the steps can be found bellow.

## Detailed steps
Configure AWS credentials for terraform setting the following variables:
```bash
export AWS_ACCESS_KEY_ID=(access key id)
export AWS_SECRET_ACCESS_KEY=(secret access key)
```
Feel free to change any of the vars inside .tf files such as cluster name,FQDN, machine types, etc.
Go inside /infraestructure/terraform folder and apply the following commands:
- Initializate the working directory that contains all the terraform configuration files
```bash
terraform init
```
- Create an execution plan to archieve the desired state of our infraestructure that includes: route53 domain, postgresql instance, s3 bucket, secrutiry groups, vpc and azs.
```bash
terraform plan
```
- Apply the changes required to reach the desired state.
```bash
terraform apply
```
After a couple of minutes all the infraestructure will be deployed.
A DNS record poiting the IP of the database so we don't need make extra changes in our app settings.


Use the templated kops cluster definition (kops_template.yml) and replace the values with the terraform outputs:
```bash
TF_OUTPUT=$(cd ../terraform && terraform output -json)
CLUSTER_NAME="$(echo ${TF_OUTPUT} | jq -r .kubernetes_cluster_name.value)"
kops toolbox template --name ${CLUSTER_NAME} --values <( echo ${TF_OUTPUT}) --template kops-template.yml --format-yaml > adevinta-k8s-cluster.yml
```
The last command will create a kops cluster definition, in order to keep secured upload it to Kops State S3:
```bash
STATE="s3://$(echo ${TF_OUTPUT} | jq -r .kops_s3_bucket.value)"
kops replace -f adevinta-k8s-cluster.yml --state ${STATE} --name ${CLUSTER_NAME} --force
```
Create a secret with your public ssh key and enerate a terraform file for the cluster configuration(Remember that you need a public Route53 zone or run the command inside a VPC otherwhise the second command will fail):
```bash
kops create secret --name k8s.adevinta-test.com sshpublickey admin -i ~/.ssh/id_rsa.pub
kops update cluster --target terraform --state ${STATE} --name ${CLUSTER_NAME} --out .
```
Afterwards run the terraform commands to deploy the Kubernetes cluster:
```bash
terraform init
terraform plan
terraform apply
```
In order to download the Kubernetes cluster context run the following commands:
```bash
kops export kubecfg --name ${CLUSTER_NAME} --state ${STATE}
kubectl config set-cluster ${CLUSTER_NAME} --server=https://api.${CLUSTER_NAME}
```
Once we have the Kubernetes context, upload it to a secret on Github called "KUBE_CONFIG_DATA" so the Giothub Actions pipeline can work.
Make sure that the cluster is accesible and nodes are healthy:
```bash
kubectl get nodes -o wide
```
Create a couple of secrets (Username and password) so the pipeline can pull and push containers to Dockerhub.
Last, make a commit and push it. Pipeline should trigger deploying the last version of the application and updating the kubernetes manifests.

## Monitoring
Monitoring is achieved using prometheus + alertmanager (Slack or mail alerts). Grafana can
be used as the frontend to check the metrics and create dashboards.
Using an slack webhook we’ll receive all the notifications in our freshly created channel
#k8smonitoring.
Add and update helm repositories:
```bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update
```
Create a dedicated namespace for monitoring objects and deploy prometheus-operator helm chart(Dont forget to replace api_url field with a valid Slack Hook URL)
```bash
kubectl create namespace monitoring
helm install adevinta-monitoring stable/prometheus-operator --skip-crds -n monitoring -f /kubernetes/monitoring/values.yml
```
Make sure that all the objects haven been succesfully deployed:
```bash
kubectl --namespace monitoring get all -l "release=adevinta-monitoring"
```

## External Access
External access is archieved using NGINX Ingress which expose and balance the access to the application.
Add and update helm repositories (Skip this if you already did it in previous steps):
```bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update
```
Deploy nginx ingress stable helm chart:
```bash
helm install adevinta-ingress stable/nginx-ingress
```
Deploy ingress manifest to the cluster
```bash
kubectl apply -f /kubernetes/ingress.yml
```
Check ingress IP in order to use it on the DNS.
```bash
kubectl get ingress
```
## Log managment
Application log management can be achieved using ELK. Logs can be collected using two
different approaches: using a filebeat daemonset (its works wonders according to my
experience) or using the sidecar pattern (extra container on each one of our application
pods) that causes a higher resource usage. Kibana can be used as the frontend to access
the logs.

## Rollback 
Rollback to last version can be made using the kubectl tool, simply run:
```bash
kubectl rollout undo deployment/adevinta-application
```
This will replace the docker image which is set in the deployment

## Clean up
To delete all the infraestructure deployed, simply run 
```bash
terraform destroy
```

## Conclusions
This POC covers how to automatically deploy a highly available Kubernetes Cluster with 3 masters and 2 worker nodes on 3 diferentes AZS and one RDS instance.
The deployment of the application is automated and provides no downtime.
The applications scales if the resource usage is exceeded, it's also accesible from anywhere and fault tolerant if there's a problem connecting with the database.
