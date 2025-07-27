import json
import boto3
import os
import logging
from datetime import datetime
from typing import Dict, Any
from decimal import Decimal

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Order Storage Lambda - Stores validated order in DynamoDB
    Part of Step Function orchestration
    """
    try:
        order_data = event
        order_id = order_data.get('order_id')
        
        logger.info(json.dumps({
            'event_type': 'order_storage_started',
            'order_id': order_id,
            'timestamp': datetime.utcnow().isoformat()
        }))
        
        # Get DynamoDB table
        table_name = os.environ['ORDERS_TABLE_NAME']
        table = dynamodb.Table(table_name)
        
        # Prepare item for DynamoDB (convert floats to Decimal)
        db_item = prepare_dynamodb_item(order_data)
        
        # Store order in DynamoDB
        table.put_item(Item=db_item)
        
        logger.info(json.dumps({
            'event_type': 'order_stored_successfully',
            'order_id': order_id,
            'table_name': table_name,
            'timestamp': datetime.utcnow().isoformat()
        }))
        
        # Return order data with storage confirmation
        return {
            **order_data,
            'storage_status': 'STORED',
            'stored_at': datetime.utcnow().isoformat(),
            'status': 'PENDING_FULFILLMENT'
        }
        
    except Exception as e:
        logger.error(json.dumps({
            'event_type': 'order_storage_error',
            'order_id': event.get('order_id'),
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }))
        
        raise e

def prepare_dynamodb_item(order_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert order data for DynamoDB storage
    Handle type conversions (float to Decimal)
    """
    item = order_data.copy()
    
    # Convert total_amount to Decimal if present
    if 'total_amount' in item and item['total_amount'] is not None:
        item['total_amount'] = Decimal(str(item['total_amount']))
    
    # Convert item prices to Decimal
    if 'items' in item and isinstance(item['items'], list):
        for order_item in item['items']:
            if 'price' in order_item and order_item['price'] is not None:
                order_item['price'] = Decimal(str(order_item['price']))
            if 'quantity' in order_item and order_item['quantity'] is not None:
                order_item['quantity'] = Decimal(str(order_item['quantity']))
    
    # Add TTL (optional - 90 days from now)
    import time
    item['ttl'] = int(time.time()) + (90 * 24 * 60 * 60)
    
    return item
