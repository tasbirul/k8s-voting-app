output "master_public_ip" {
  description = "Public IP of the Master node"
  value       = aws_instance.master.public_ip
}

output "master_private_ip" {
  description = "Private IP of the Master node (used by kubeadm advertise address)"
  value       = aws_instance.master.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of the Worker nodes"
  value       = aws_instance.worker[*].public_ip
}

output "ssh_master_command" {
  description = "Command to SSH into the master node"
  value       = "ssh -i ~/Documents/${var.key_name}.pem ubuntu@${aws_instance.master.public_ip}"
}

output "ansible_inventory_check_command" {
  description = "Command to verify the Ansible dynamic inventory discovers all nodes"
  value       = "cd ansible && ansible-inventory -i inventory/aws_ec2.yml --list"
}