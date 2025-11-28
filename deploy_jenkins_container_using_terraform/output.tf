output "instance_ip" {
  value = aws_instance.iac_instance.public_ip
}