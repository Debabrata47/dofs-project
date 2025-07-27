import json
import boto3
import os
import logging
import random
from datetime import datetime
from typing import Dict, Any
from decimal import Decimal

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Fulfillment Lambda - Processes orders from SQS queue
    Updates order status with 70% success rate simulation
    """
    try:
        # Process each record from SQS
        for record in event['Records']:
            process_order_message(record)
        
        return {'statusCode': 200, 'body': 'Orders processed successfully'}
        
    except Exception as e:
        logger.error(json.dumps({
            'event_type': 'fulfillment_lambda_error',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }))
        raise e

def process_order_message(record: Dict[str, Any]) -> None:
    """
    Process individual order message from SQS
    """
    try:
        # Parse message body
        message_body = json.loads(record['body'])
        order_data = message_body
        order_id = order_data.get('order_id')
        
        logger.info(json.dumps({
            'event_type': 'fulfillment_started',
            'order_id': order_id,
            'message_id': record.get('messageId'),
            'timestamp': datetime.utcnow().isoformat()
        }))
        
        # Simulate order fulfillment with 70% success rate
        fulfillment_successful = simulate_fulfillment()
        
        # Get DynamoDB tables
        orders_table_name = os.environ['ORDERS_TABLE_NAME']
        failed_orders_table_name = os.environ['FAILED_ORDERS_TABLE_NAME']
        
        orders_table = dynamodb.Table(orders_table_name)
        failed_orders_table = dynamodb.Table(failed_orders_table_name)
        
        if fulfillment_successful:
            # Update order status to FULFILLED
            update_order_status(orders_table, order_id, 'FULFILLED')
            
            logger.info(json.dumps({
                'event_type': 'fulfillment_successful',
                'order_id': order_id,
                'timestamp': datetime.utcnow().isoformat()
            }))
        else:
            # Update order status to FAILED
            update_order_status(orders_table, order_id, 'FAILED')
            
            # Check if this message should go to DLQ
            receive_count = int(record.get('attributes', {}).get('ApproximateReceiveCount', 1))
            max_receive_count = int(os.environ.get('MAX_RECEIVE_COUNT', 3))
            
            if receive_count >= max_receive_count:
                # Store in failed orders table
                store_failed_order(failed_orders_table, order_data, record)
                
                logger.error(json.dumps({
                    'event_type': 'order_moved_to_dlq',
                    'order_id': order_id,
                    'receive_count': receive_count,
                    'max_receive_count': max_receive_count,
                    'timestamp': datetime.utcnow().isoformat()
                }))
            else:
                logger.warning(json.dumps({
                    'event_type': 'fulfillment_failed_retrying',
                    'order_id': order_id,
                    'receive_count': receive_count,
                    'timestamp': datetime.utcnow().isoformat()
                }))
                
                # Re-raise exception to trigger retry
                raise Exception(f"Fulfillment failed for order {order_id}")
            
    except Exception as e:
        logger.error(json.dumps({
            'event_type': 'process_order_error',
            'order_id': order_data.get('order_id') if 'order_data' in locals() else 'unknown',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }))
        raise e

def simulate_fulfillment() -> bool:
    """
    Simulate order fulfillment with 70% success rate
    """
    return random.random() < 0.7

def update_order_status(table, order_id: str, status: str) -> None:
    """
    Update order status in DynamoDB
    """
    try:
        table.update_item(
            Key={'order_id': order_id},
            UpdateExpression='SET #status = :status, updated_at = :updated_at',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': status,
                ':updated_at': datetime.utcnow().isoformat()
            }
        )
        
        logger.info(json.dumps({
            'event_type': 'order_status_updated',
            'order_id': order_id,
            'new_status': status,
            'timestamp': datetime.utcnow().isoformat()
        }))
        
    except Exception as e:
        logger.error(json.dumps({
            'event_type': 'order_status_update_error',
            'order_id': order_id,
            'status': status,
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }))
        raise e

def store_failed_order(table, order_data: Dict[str, Any], sqs_record: Dict[str, Any]) -> None:
    """
    Store failed order in failed_orders table
    """
    try:
        failed_order_item = {
            'order_id': order_data.get('order_id'),
            'original_order': order_data,
            'failure_reason': 'Fulfillment failed after max retries',
            'failed_at': datetime.utcnow().isoformat(),
            'sqs_message_id': sqs_record.get('messageId'),
            'receive_count': int(sqs_record.get('attributes', {}).get('ApproximateReceiveCount', 1)),
            'ttl': int(datetime.utcnow().timestamp()) + (365 * 24 * 60 * 60)  # 1 year TTL
        }
        
        table.put_item(Item=failed_order_item)
        
        logger.info(json.dumps({
            'event_type': 'failed_order_stored',
            'order_id': order_data.get('order_id'),
            'timestamp': datetime.utcnow().isoformat()
        }))
        
    except Exception as e:
        logger.error(json.dumps({
            'event_type': 'failed_order_storage_error',
            'order_id': order_data.get('order_id'),
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }))
        raise e
