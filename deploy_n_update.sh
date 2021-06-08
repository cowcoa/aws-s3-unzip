#!/bin/bash

arg_count=$#
script_name=$(basename $0)
stack_action=update

if test $arg_count -eq 1
then
    if [[ $1 =~ ^(create|update)$ ]]; then
        stack_action=$1
    else
        echo "Stack Action must be create or update"
        echo "Usage: $script_name [create|update]"
        exit -1
    fi
else
    echo "Usage: $script_name [create|update] src-bucket BUCKET-NAME dst-bucket BUCKET-NAME config-bucket BUCKET-NAME"
    echo ""
    echo "Examples:"
    echo "$script_name create src-bucket poc-zxaws-ab-mirror-us-east-1 dst-bucket poc-zxaws-ab-us-east-1 config-bucket zxaws-ab-serverless-mirror-us-east-1"
    echo ""
    exit 0
fi

input_template_file="iam_template.yaml"
output_template_file="packaged-template-output.yaml"
s3_bucket_name="zxaws-ab-serverless-mirror-us-east-1"
cf_stack_name="zxaws-poc-unzip-handlers"
cf_change_set_name="$cf_stack_name-change-set"

echo "${stack_action^^} $cf_stack_name cloudformation stack..."
if [ $stack_action = update ]; then
    echo "NOTE: Before UPDATE a stack, be sure you already have the corresponding stack in cloudformation"
fi;

if [ -f $output_template_file ]
then
	rm -rf $output_template_file
fi

echo "Packaging..."
aws cloudformation package \
    --template-file $input_template_file \
    --s3-bucket $s3_bucket_name \
    --output-template-file $output_template_file

result=$?

if test $result -ne 0
then
    echo "Failed to package template $input_template_file"
	exit $result
fi

echo "Uploading template file..."
aws s3api put-object \
    --bucket $s3_bucket_name \
    --key $output_template_file \
    --body $output_template_file

echo "Creating change set..."
aws cloudformation create-change-set \
    --change-set-type ${stack_action^^} \
    --stack-name $cf_stack_name \
    --change-set-name $cf_change_set_name \
    --template-url https://s3.amazonaws.com/$s3_bucket_name/$output_template_file \
    --capabilities CAPABILITY_IAM \
    --parameters ParameterKey="SrcBucketName",ParameterValue=$deployment_type \
                 ParameterKey="DstBucketName",ParameterValue=$maker_task_queue
                 
result=$?

if test $result -ne 0
then
    echo "Failed to create change set $cf_change_set_name"
	exit $result
fi

echo "Waiting for change-set-create-complete..."
aws cloudformation wait \
    change-set-create-complete \
    --stack-name $cf_stack_name \
    --change-set-name $cf_change_set_name
    
result=$?

if test $result -ne 0
then
    echo "create-change-set return failed"
	exit $result
fi

echo "Executing change set..."
aws cloudformation execute-change-set \
    --change-set-name $cf_change_set_name \
    --stack-name $cf_stack_name

echo "Waiting for stack executing complete..."
aws cloudformation wait \
    stack-${stack_action}-complete \
    --stack-name $cf_stack_name

result=$?

if test $result -ne 0
then
    echo "Deleting change set..."
    aws cloudformation delete-change-set \
        --stack-name $cf_stack_name \
        --change-set-name $cf_change_set_name
fi

if [ -f $output_template_file ]
then
	rm -rf $output_template_file
fi

echo "Done"
