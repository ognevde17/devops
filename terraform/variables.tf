variable "http_port" {
  description = "Nonstandard HTTP port on the VM loopback interface."
  type        = number
  default     = 8088
  validation {
    condition     = var.http_port >= 1024 && var.http_port <= 65535 && floor(var.http_port) == var.http_port
    error_message = "Choose an integer TCP port from 1024 to 65535."
  }
}
