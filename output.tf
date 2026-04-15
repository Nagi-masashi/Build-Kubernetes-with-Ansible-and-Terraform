output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}

output "bastion_name" {
  value = aws_instance.bastion.tags["Name"]
}

output "worker_ip" {
  value = aws_instance.WorkerNode[*].private_ip
}

output "worker_names" {
  value = aws_instance.WorkerNode[*].tags["Name"]
}
