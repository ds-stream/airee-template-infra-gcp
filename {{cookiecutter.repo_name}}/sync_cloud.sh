#!/bin/bash
#import json variables
for env in $(cat status.json | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ); do export $env; done

#auth gcp
gcloud auth activate-service-account ${GOOGLE_IMPERSONATE_SERVICE_ACCOUNT} --key-file=${GOOGLE_APPLICATION_CREDENTIALS}
gcloud config set project ${GCP_PROJECT}

#sync infr
if [ "${status}" == "up" ]; then
	cd service && terraform init && terraform apply --auto-approve && sleep 60 && kubectl get service airflow-webserver -n airflow
elif [ "${status}" == "down" ]; then
	cd service && terraform init && sh ../destroy_infra.sh
else 
     echo "Json status does not allow to apply changes"
fi
