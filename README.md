# Unzip file on S3
![alt text](../master/architecture_diagram.png?raw=true)

# Introduction  

Automatically decompress zip files from SRC s3 bucket and sync the unzipped files to DST s3 bucket.

The project can accelerate massive small file uploading speed by packing files into a ZIP file, uploading the ZIP file to the SRC S3 bucket, unzipping the ZIP file, and saving unzipped files to the DST S3 bucket.
 

# Files

- unzip-file - Code for the application's Lambda function.

- config.json - Configurations of email addresses for notifications.

- iam_template.yaml - The Amazon CloudFormation template file that defines the IAM role for the Lambda function, a Lambda function, a source S3 bucket, and a destination S3 bucket for testing.

- template.yaml - A template that defines the application's AWS resources.

  

The application uses several AWS resources, including **Lambda functions** and  **Amazon SES**, and **Amazon S3**. These resources are defined in the `iam_template.yaml` or `template.yaml` file in this project. You can update the template to add AWS resources through the same deployment process that updates your application code.

## Lambda functions

## unzip-file
- index.js - Extract the zip file location from S3 event messages and unzip the ZIP file, and save unpacked files to the DST S3 bucket, and send a notification to per-configured email addresses.


# Deployment

## Prerequisites
- Amazon IAM users and/or roles
- A SRC S3 bucket
- A DST S3 bucket
- A verified Amazon Simple Email Service domain

## Amzon IAM users and roles
- An IAM role for Lambda functions to read and write files from/onto the source and DST S3 buckets and be able to send emails via SES.

