#!/bin/bash
#import json variables
for env in $(cat status.json | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ); do export $env; done

#auth gcp
gcloud config set project {{cookiecutter.project_id}}

#sync infr
if [ "${status}" == "up" ]; then
	cd service && terraform init && terraform apply --auto-approve
elif [ "${status}" == "down" ]; then
	gcloud container clusters get-credentials {{cookiecutter.cluster_name}}-{{cookiecutter.workspace}} --region {{cookiecutter.region}} --project {{cookiecutter.project_id}} && \
	cd service && terraform init && sh ../destroy_infra.sh
else 
     echo "Json status does not allow to apply changes"
fi
