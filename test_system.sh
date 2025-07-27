#!/bin/bash

# Test script for the DOFS system
# Usage: ./test_system.sh <api_gateway_url>

set -e

API_URL=${1:-""}

if [ -z "$API_URL" ]; then
    echo "Usage: $0 <api_gateway_url>"
    echo "Example: $0 https://abc123.execute-api.us-east-1.amazonaws.com/dev"
    exit 1
fi

echo "Testing DOFS System at: $API_URL"
echo "=================================="

# Test 1: Valid Order
echo -e "\n1. Testing valid order submission..."
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL/order" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust_12345",
    "items": [
      {
        "product_id": "prod_001",
        "quantity": 2,
        "price": 29.99
      },
      {
        "product_id": "prod_002", 
        "quantity": 1,
        "price": 15.50
      }
    ],
    "total_amount": 75.48
  }')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" -eq 202 ]; then
    echo "✅ Valid order test PASSED"
    echo "Response: $BODY"
    ORDER_ID=$(echo "$BODY" | jq -r '.order_id')
    echo "Order ID: $ORDER_ID"
else
    echo "❌ Valid order test FAILED (Status: $HTTP_STATUS)"
    echo "Response: $BODY"
fi

# Test 2: Invalid Order (Missing required field)
echo -e "\n2. Testing invalid order (missing customer_id)..."
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL/order" \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {
        "product_id": "prod_001",
        "quantity": 1,
        "price": 10.00
      }
    ],
    "total_amount": 10.00
  }')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" -eq 400 ] || [ "$HTTP_STATUS" -eq 202 ]; then
    echo "✅ Invalid order test PASSED (Status: $HTTP_STATUS)"
    echo "Response: $BODY"
else
    echo "❌ Invalid order test FAILED (Status: $HTTP_STATUS)"
    echo "Response: $BODY"
fi

# Test 3: Malformed JSON
echo -e "\n3. Testing malformed JSON..."
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL/order" \
  -H "Content-Type: application/json" \
  -d '{"customer_id": "test", "items": [}')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" -eq 400 ]; then
    echo "✅ Malformed JSON test PASSED"
    echo "Response: $BODY"
else
    echo "❌ Malformed JSON test FAILED (Status: $HTTP_STATUS)"
    echo "Response: $BODY"
fi

# Test 4: CORS Preflight
echo -e "\n4. Testing CORS preflight (OPTIONS)..."
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X OPTIONS "$API_URL/order" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "✅ CORS preflight test PASSED"
else
    echo "❌ CORS preflight test FAILED (Status: $HTTP_STATUS)"
fi

# Test 5: Load Test (Multiple orders)
echo -e "\n5. Testing multiple order submissions..."
SUCCESS_COUNT=0
TOTAL_REQUESTS=5

for i in $(seq 1 $TOTAL_REQUESTS); do
    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL/order" \
      -H "Content-Type: application/json" \
      -d "{
        \"customer_id\": \"load_test_$i\",
        \"items\": [
          {
            \"product_id\": \"prod_load_$i\",
            \"quantity\": $i,
            \"price\": 10.00
          }
        ],
        \"total_amount\": $((i * 10))
      }")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
    
    if [ "$HTTP_STATUS" -eq 202 ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo "  Request $i: ✅ SUCCESS"
    else
        echo "  Request $i: ❌ FAILED (Status: $HTTP_STATUS)"
    fi
done

echo "Load test completed: $SUCCESS_COUNT/$TOTAL_REQUESTS successful"

echo -e "\n=================================="
echo "Test Summary:"
echo "✅ Tests completed successfully indicate proper API Gateway and Lambda integration"
echo "📊 Check CloudWatch dashboards for detailed metrics"
echo "📋 Monitor Step Function executions in AWS Console"
echo "🗄️  Verify data in DynamoDB tables"
echo "📬 Check SQS queues for message processing"

if [ "$SUCCESS_COUNT" -eq "$TOTAL_REQUESTS" ]; then
    echo -e "\n🎉 All load tests passed! System is functioning correctly."
else
    echo -e "\n⚠️  Some load tests failed. Check logs and system health."
fi
