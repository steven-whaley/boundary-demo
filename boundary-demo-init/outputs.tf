output "server_ip_address" {
  description = "The server IP Address"
  value = aws_instance.server.public_ip
}