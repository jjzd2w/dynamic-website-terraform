import json
import boto3
import os
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    try:
        # Get the current string from DynamoDB
        response = table.get_item(
            Key={
                'id': 'current'
            }
        )
        
        current_string = response.get('Item', {}).get('current_string', 'dynamic string')
        
        # Generate the HTML content
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Dynamic String Website</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 40px; text-align: center; }}
                h1 {{ color: #333; }}
                .info {{ margin-top: 20px; padding: 10px; background-color: #f5f5f5; border-radius: 5px; }}
            </style>
        </head>
        <body>
            <h1>The saved string is: {current_string}</h1>
            <div class="info">
                <p>To update the string, send a POST request to: {os.environ.get('API_URL', 'API endpoint')}/update</p>
                <p>With JSON body: {{"string": "your new string"}}</p>
            </div>
        </body>
        </html>
        """
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'text/html',
                'Access-Control-Allow-Origin': '*'
            },
            'body': html_content
        }
        
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
