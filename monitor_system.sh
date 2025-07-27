#!/bin/bash

# Monitor DOFS system health and metrics
# Usage: ./monitor_system.sh [environment]

set -e

ENVIRONMENT=${1:-"dev"}
PROJECT_NAME="dofs"

echo "Monitoring DOFS System Health"
echo "=============================="
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_NAME"
echo ""

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo "❌ AWS CLI not configured or credentials invalid"
        exit 1
    fi
    echo "✅ AWS CLI configured"
}

# Function to get CloudWatch metric statistics
get_metric_stats() {
    local namespace=$1
    local metric_name=$2
    local dimensions=$3
    local start_time=$4
    local end_time=$5
    
    aws cloudwatch get-metric-statistics \
        --namespace "$namespace" \
        --metric-name "$metric_name" \
        --dimensions "$dimensions" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 300 \
        --statistics Sum,Average \
        --query 'Datapoints[0].Sum' \
        --output text 2>/dev/null || echo "0"
}

# Check AWS CLI
check_aws_cli

# Set time range (last 1 hour)
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S")
START_TIME=$(date -u -d '1 hour ago' +"%Y-%m-%dT%H:%M:%S")

echo "Time range: $START_TIME to $END_TIME"
echo ""

# 1. API Gateway Health
echo "1. API Gateway Metrics"
echo "----------------------"
API_NAME="${PROJECT_NAME}-order-api-${ENVIRONMENT}"
API_COUNT=$(get_metric_stats "AWS/ApiGateway" "Count" "Name=ApiName,Value=$API_NAME Name=Stage,Value=$ENVIRONMENT" "$START_TIME" "$END_TIME")
API_4XX=$(get_metric_stats "AWS/ApiGateway" "4XXError" "Name=ApiName,Value=$API_NAME Name=Stage,Value=$ENVIRONMENT" "$START_TIME" "$END_TIME")
API_5XX=$(get_metric_stats "AWS/ApiGateway" "5XXError" "Name=ApiName,Value=$API_NAME Name=Stage,Value=$ENVIRONMENT" "$START_TIME" "$END_TIME")

echo "  Total Requests: $API_COUNT"
echo "  4XX Errors: $API_4XX"
echo "  5XX Errors: $API_5XX"

if [ "$API_COUNT" -gt 0 ]; then
    ERROR_RATE=$(echo "scale=2; ($API_4XX + $API_5XX) * 100 / $API_COUNT" | bc -l 2>/dev/null || echo "0")
    echo "  Error Rate: ${ERROR_RATE}%"
fi
echo ""

# 2. Lambda Function Health
echo "2. Lambda Function Metrics"
echo "--------------------------"
LAMBDA_FUNCTIONS=(
    "${PROJECT_NAME}-api-handler-${ENVIRONMENT}"
    "${PROJECT_NAME}-validator-${ENVIRONMENT}"
    "${PROJECT_NAME}-order-storage-${ENVIRONMENT}"
    "${PROJECT_NAME}-fulfill-order-${ENVIRONMENT}"
)

for func in "${LAMBDA_FUNCTIONS[@]}"; do
    echo "  Function: $func"
    
    INVOCATIONS=$(get_metric_stats "AWS/Lambda" "Invocations" "Name=FunctionName,Value=$func" "$START_TIME" "$END_TIME")
    ERRORS=$(get_metric_stats "AWS/Lambda" "Errors" "Name=FunctionName,Value=$func" "$START_TIME" "$END_TIME")
    THROTTLES=$(get_metric_stats "AWS/Lambda" "Throttles" "Name=FunctionName,Value=$func" "$START_TIME" "$END_TIME")
    
    echo "    Invocations: $INVOCATIONS"
    echo "    Errors: $ERRORS"
    echo "    Throttles: $THROTTLES"
    
    if [ "$INVOCATIONS" -gt 0 ]; then
        ERROR_RATE=$(echo "scale=2; $ERRORS * 100 / $INVOCATIONS" | bc -l 2>/dev/null || echo "0")
        echo "    Error Rate: ${ERROR_RATE}%"
    fi
    echo ""
done

# 3. Step Function Health
echo "3. Step Function Metrics"
echo "------------------------"
STEP_FUNCTION_NAME="${PROJECT_NAME}-order-processing-${ENVIRONMENT}"

# Get Step Function ARN
SF_ARN=$(aws stepfunctions list-state-machines \
    --query "stateMachines[?name=='$STEP_FUNCTION_NAME'].stateMachineArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$SF_ARN" ]; then
    SF_STARTED=$(get_metric_stats "AWS/States" "ExecutionsStarted" "Name=StateMachineArn,Value=$SF_ARN" "$START_TIME" "$END_TIME")
    SF_SUCCEEDED=$(get_metric_stats "AWS/States" "ExecutionsSucceeded" "Name=StateMachineArn,Value=$SF_ARN" "$START_TIME" "$END_TIME")
    SF_FAILED=$(get_metric_stats "AWS/States" "ExecutionsFailed" "Name=StateMachineArn,Value=$SF_ARN" "$START_TIME" "$END_TIME")
    
    echo "  Executions Started: $SF_STARTED"
    echo "  Executions Succeeded: $SF_SUCCEEDED"
    echo "  Executions Failed: $SF_FAILED"
    
    if [ "$SF_STARTED" -gt 0 ]; then
        SUCCESS_RATE=$(echo "scale=2; $SF_SUCCEEDED * 100 / $SF_STARTED" | bc -l 2>/dev/null || echo "0")
        echo "  Success Rate: ${SUCCESS_RATE}%"
    fi
else
    echo "  ⚠️  Step Function not found or no permissions"
fi
echo ""

# 4. SQS Queue Health
echo "4. SQS Queue Metrics"
echo "--------------------"
ORDER_QUEUE="${PROJECT_NAME}-order-queue-${ENVIRONMENT}"
ORDER_DLQ="${PROJECT_NAME}-order-dlq-${ENVIRONMENT}"

for queue in "$ORDER_QUEUE" "$ORDER_DLQ"; do
    echo "  Queue: $queue"
    
    SENT=$(get_metric_stats "AWS/SQS" "NumberOfMessagesSent" "Name=QueueName,Value=$queue" "$START_TIME" "$END_TIME")
    RECEIVED=$(get_metric_stats "AWS/SQS" "NumberOfMessagesReceived" "Name=QueueName,Value=$queue" "$START_TIME" "$END_TIME")
    VISIBLE=$(aws sqs get-queue-attributes \
        --queue-url "https://sqs.$(aws configure get region).amazonaws.com/$(aws sts get-caller-identity --query Account --output text)/$queue" \
        --attribute-names ApproximateNumberOfVisibleMessages \
        --query 'Attributes.ApproximateNumberOfVisibleMessages' \
        --output text 2>/dev/null || echo "0")
    
    echo "    Messages Sent: $SENT"
    echo "    Messages Received: $RECEIVED"
    echo "    Messages Visible: $VISIBLE"
    
    if [ "$queue" = "$ORDER_DLQ" ] && [ "$VISIBLE" -gt 5 ]; then
        echo "    ⚠️  DLQ has $VISIBLE messages (threshold: 5)"
    fi
    echo ""
done

# 5. DynamoDB Health
echo "5. DynamoDB Table Metrics"
echo "-------------------------"
ORDERS_TABLE="${PROJECT_NAME}-orders-${ENVIRONMENT}"
FAILED_ORDERS_TABLE="${PROJECT_NAME}-failed-orders-${ENVIRONMENT}"

for table in "$ORDERS_TABLE" "$FAILED_ORDERS_TABLE"; do
    echo "  Table: $table"
    
    # Check if table exists
    if aws dynamodb describe-table --table-name "$table" >/dev/null 2>&1; then
        ITEM_COUNT=$(aws dynamodb describe-table \
            --table-name "$table" \
            --query 'Table.ItemCount' \
            --output text 2>/dev/null || echo "0")
        
        TABLE_SIZE=$(aws dynamodb describe-table \
            --table-name "$table" \
            --query 'Table.TableSizeBytes' \
            --output text 2>/dev/null || echo "0")
        
        echo "    Item Count: $ITEM_COUNT"
        echo "    Table Size: $(($TABLE_SIZE / 1024)) KB"
        
        # Get recent read/write metrics
        READS=$(get_metric_stats "AWS/DynamoDB" "ConsumedReadCapacityUnits" "Name=TableName,Value=$table" "$START_TIME" "$END_TIME")
        WRITES=$(get_metric_stats "AWS/DynamoDB" "ConsumedWriteCapacityUnits" "Name=TableName,Value=$table" "$START_TIME" "$END_TIME")
        
        echo "    Read Capacity Used: $READS"
        echo "    Write Capacity Used: $WRITES"
    else
        echo "    ❌ Table not found or no permissions"
    fi
    echo ""
done

# 6. CloudWatch Alarms Status
echo "6. CloudWatch Alarms"
echo "--------------------"
ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "$PROJECT_NAME" \
    --query 'MetricAlarms[*].[AlarmName,StateValue]' \
    --output text 2>/dev/null || echo "")

if [ -n "$ALARMS" ]; then
    while IFS=$'\t' read -r alarm_name state; do
        if [ "$state" = "OK" ]; then
            echo "  ✅ $alarm_name: $state"
        elif [ "$state" = "ALARM" ]; then
            echo "  🚨 $alarm_name: $state"
        else
            echo "  ⚠️  $alarm_name: $state"
        fi
    done <<< "$ALARMS"
else
    echo "  No alarms found or no permissions"
fi
echo ""

# 7. Recent Errors (CloudWatch Logs)
echo "7. Recent Error Summary"
echo "----------------------"
LOG_GROUPS=(
    "/aws/lambda/${PROJECT_NAME}-api-handler-${ENVIRONMENT}"
    "/aws/lambda/${PROJECT_NAME}-validator-${ENVIRONMENT}"
    "/aws/lambda/${PROJECT_NAME}-order-storage-${ENVIRONMENT}"
    "/aws/lambda/${PROJECT_NAME}-fulfill-order-${ENVIRONMENT}"
)

TOTAL_ERRORS=0
for log_group in "${LOG_GROUPS[@]}"; do
    ERROR_COUNT=$(aws logs filter-log-events \
        --log-group-name "$log_group" \
        --start-time "$(date -d '1 hour ago' +%s)000" \
        --filter-pattern "ERROR" \
        --query 'length(events)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo "  $log_group: $ERROR_COUNT errors"
        TOTAL_ERRORS=$((TOTAL_ERRORS + ERROR_COUNT))
    fi
done

if [ "$TOTAL_ERRORS" -eq 0 ]; then
    echo "  ✅ No errors found in Lambda logs"
else
    echo "  ⚠️  Total errors in last hour: $TOTAL_ERRORS"
fi
echo ""

# 8. System Health Summary
echo "8. System Health Summary"
echo "========================"

HEALTH_SCORE=100

# Deduct points for various issues
if [ "$API_5XX" -gt 0 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 20))
    echo "  ⚠️  API Gateway 5XX errors detected"
fi

if [ "$TOTAL_ERRORS" -gt 10 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 15))
    echo "  ⚠️  High error count in logs"
fi

# Check DLQ depth
DLQ_DEPTH=$(aws sqs get-queue-attributes \
    --queue-url "https://sqs.$(aws configure get region).amazonaws.com/$(aws sts get-caller-identity --query Account --output text)/$ORDER_DLQ" \
    --attribute-names ApproximateNumberOfVisibleMessages \
    --query 'Attributes.ApproximateNumberOfVisibleMessages' \
    --output text 2>/dev/null || echo "0")

if [ "$DLQ_DEPTH" -gt 5 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 25))
    echo "  🚨 DLQ depth critical: $DLQ_DEPTH messages"
fi

if [ "$HEALTH_SCORE" -ge 90 ]; then
    echo "  🎉 System Health: EXCELLENT ($HEALTH_SCORE/100)"
elif [ "$HEALTH_SCORE" -ge 70 ]; then
    echo "  ✅ System Health: GOOD ($HEALTH_SCORE/100)"
elif [ "$HEALTH_SCORE" -ge 50 ]; then
    echo "  ⚠️  System Health: FAIR ($HEALTH_SCORE/100)"
else
    echo "  🚨 System Health: POOR ($HEALTH_SCORE/100)"
fi

echo ""
echo "Monitor completed at $(date)"
echo "For detailed metrics, visit CloudWatch Dashboard in AWS Console"
