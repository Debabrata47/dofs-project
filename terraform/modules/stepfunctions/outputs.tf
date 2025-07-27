output "state_machine_arn" {
  description = "ARN of the Step Function state machine"
  value       = aws_sfn_state_machine.order_processing.arn
}

output "state_machine_name" {
  description = "Name of the Step Function state machine"
  value       = aws_sfn_state_machine.order_processing.name
}

output "step_function_role_arn" {
  description = "ARN of the Step Function execution role"
  value       = aws_iam_role.step_function_role.arn
}
