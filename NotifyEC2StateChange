import json
import boto3

sns = boto3.client('sns')
ec2 = boto3.client('ec2')

TOPIC_ARN = 'your-SNS-ARN-here'

def lambda_handler(event, context):
    instance_id = event['detail']['instance-id']
    state = event['detail']['state']
    
    # Get the instance name from tags
    instance_name = "Unknown"
    try:
        response = ec2.describe_instances(InstanceIds=[instance_id])
        tags = response['Reservations'][0]['Instances'][0].get('Tags', [])
        for tag in tags:
            if tag['Key'] == 'Name':
                instance_name = tag['Value']
                break
    except Exception as e:
        instance_name = f"Error fetching name: {str(e)}"
    
    # Construct the message
    message = (
        f"EC2 instance has changed state:\n"
        f"Instance ID: {instance_id}\n"
        f"Instance Name: {instance_name}\n"
        f"New State: {state}"
    )
    
    # Publish to SNS
    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject='EC2 State Change Notification',
        Message=message
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Notification sent!')
    }
