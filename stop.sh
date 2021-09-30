#!/bin/sh

cd terraform && terraform init && terraform destroy -auto-approve
