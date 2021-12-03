#!/bin/bash
# Variables throughout the project.

# Every resources created on AWS will be named with this prefix.
project_name="aws-s3unzip"
# AWS Account Number for this deployment.
aws_account_id="$(aws sts get-caller-identity --output text --query 'Account')"
# Project will be deloyed on this region.
deployment_region="$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')"
# S3 bucket for intermediate/temp files during deployment.
s3_deployment_bucket="$project_name-deployment-$deployment_region"
# S3 bucket holding the zip files that need to be uploaded.
s3_src_bucket="$project_name-src-$deployment_region"
# S3 bucket holding the unzipped files that synced by UnzipLambda.
s3_dst_bucket="$project_name-dst-$deployment_region"
# Whether to send e-mail after file sync.
ses_enable="false"

echo "config.sh imported."
