import json
import boto3
import uuid
import os
import logging
from datetime import datetime
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_step_function_arn() -> str:
    """
    Fetch the ARN of the Step Function based on environment variables
    """
    sfn = boto3.client("stepfunctions")
    env = os.environ["ENVIRONMENT"]
    project = os.environ["PROJECT_NAME"]
    target_name = f"{project}-{env}-stepfunction"

    response = sfn.list_state_machines()

    for sm in response["stateMachines"]:
        if sm["name"] == target_name:
            return sm["stateMachineArn"]

    raise Exception(f"Step Function '{target_name}' not found")

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    API Handler Lambda - Entry point for order processing
    Accepts POST /order requests and triggers Step Function execution
    """
    try:
        # Extract request body
        body = json.loads(event.get('body', '{}'))

        # Validate basic request structure
        if not body:
            return create_response(400, {'error': 'Request body is required'})

        # Generate unique order ID
        order_id = str(uuid.uuid4())

        # Create order payload with metadata
        order_payload = {
            'order_id': order_id,
            'customer_id': body.get('customer_id'),
            'items': body.get('items', []),
            'total_amount': body.get('total_amount'),
            'timestamp': datetime.utcnow().isoformat(),
            'status': 'INITIATED'
        }

        # Log the incoming request
        logger.info(json.dumps({
            'event_type': 'order_received',
            'order_id': order_id,
            'customer_id': order_payload.get('customer_id'),
            'timestamp': order_payload['timestamp']
        }))

        # Fetch Step Function ARN dynamically
        step_function_arn = get_step_function_arn()

        # Start Step Function execution
        stepfunctions = boto3.client('stepfunctions')
        response = stepfunctions.start_execution(
            stateMachineArn=step_function_arn,
            name=f"order-{order_id}-{int(datetime.utcnow().timestamp())}",
            input=json.dumps(order_payload)
        )

        logger.info(json.dumps({
            'event_type': 'step_function_started',
            'order_id': order_id,
            'execution_arn': response['executionArn'],
            'timestamp': datetime.utcnow().isoformat()
        }))

        return create_response(202, {
            'message': 'Order received and processing started',
            'order_id': order_id,
            'execution_arn': response['executionArn']
        })

    except json.JSONDecodeError:
        logger.error('Invalid JSON in request body')
        return create_response(400, {'error': 'Invalid JSON in request body'})

    except Exception as e:
        logger.error(json.dumps({
            'event_type': 'api_handler_error',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }))
        return create_response(500, {'error': 'Internal server error'})

def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Create standardized API Gateway response
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'POST, OPTIONS'
        },
        'body': json.dumps(body)
    }
