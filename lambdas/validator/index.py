import json
import logging
from datetime import datetime
from typing import Dict, Any, List

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Validator Lambda - Validates order data
    Part of Step Function orchestration
    """
    try:
        order_data = event
        order_id = order_data.get('order_id')
        
        logger.info(json.dumps({
            'event_type': 'validation_started',
            'order_id': order_id,
            'timestamp': datetime.utcnow().isoformat()
        }))
        
        # Validate order structure
        validation_errors = validate_order(order_data)
        
        if validation_errors:
            logger.error(json.dumps({
                'event_type': 'validation_failed',
                'order_id': order_id,
                'errors': validation_errors,
                'timestamp': datetime.utcnow().isoformat()
            }))
            
            # Return validation failure
            return {
                **order_data,
                'validation_status': 'FAILED',
                'validation_errors': validation_errors,
                'timestamp': datetime.utcnow().isoformat()
            }
        
        logger.info(json.dumps({
            'event_type': 'validation_successful',
            'order_id': order_id,
            'timestamp': datetime.utcnow().isoformat()
        }))
        
        # Return validated order
        return {
            **order_data,
            'validation_status': 'PASSED',
            'validated_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(json.dumps({
            'event_type': 'validator_error',
            'order_id': event.get('order_id'),
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }))
        
        raise e

def validate_order(order_data: Dict[str, Any]) -> List[str]:
    """
    Validate order data and return list of validation errors
    """
    errors = []
    
    # Check required fields
    required_fields = ['order_id', 'customer_id', 'items', 'total_amount']
    for field in required_fields:
        if not order_data.get(field):
            errors.append(f"Missing required field: {field}")
    
    # Validate customer_id format
    customer_id = order_data.get('customer_id')
    if customer_id and not isinstance(customer_id, str):
        errors.append("customer_id must be a string")
    
    # Validate items
    items = order_data.get('items', [])
    if not isinstance(items, list):
        errors.append("items must be a list")
    elif len(items) == 0:
        errors.append("Order must contain at least one item")
    else:
        for i, item in enumerate(items):
            if not isinstance(item, dict):
                errors.append(f"Item {i} must be an object")
                continue
                
            item_required_fields = ['product_id', 'quantity', 'price']
            for field in item_required_fields:
                if field not in item:
                    errors.append(f"Item {i} missing required field: {field}")
            
            # Validate quantity and price are positive numbers
            if 'quantity' in item:
                try:
                    quantity = float(item['quantity'])
                    if quantity <= 0:
                        errors.append(f"Item {i} quantity must be positive")
                except (ValueError, TypeError):
                    errors.append(f"Item {i} quantity must be a number")
            
            if 'price' in item:
                try:
                    price = float(item['price'])
                    if price < 0:
                        errors.append(f"Item {i} price must be non-negative")
                except (ValueError, TypeError):
                    errors.append(f"Item {i} price must be a number")
    
    # Validate total_amount
    total_amount = order_data.get('total_amount')
    if total_amount is not None:
        try:
            total = float(total_amount)
            if total < 0:
                errors.append("total_amount must be non-negative")
        except (ValueError, TypeError):
            errors.append("total_amount must be a number")
    
    return errors
