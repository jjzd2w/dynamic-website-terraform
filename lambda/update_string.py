import json
import boto3
import os
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    try:
        # Parse the request body
        if 'body' in event:
            if event.get('isBase64Encoded', False):
                body = json.loads(base64.b64decode(event['body']).decode('utf-8'))
            else:
                body = json.loads(event['body'])
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'No body provided'})
            }
        
        new_string = body.get('string', '').strip()
        
        if not new_string:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'String parameter is required'})
            }
        
        # Update the string in DynamoDB
        table.put_item(
            Item={
                'id': 'current',
                'current_string': new_string
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'String updated successfully',
                'new_string': new_string
            })
        }
        
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
