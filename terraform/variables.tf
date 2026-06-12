variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Name prefix for all resources."
  type        = string
  default     = "cicd-frontend"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro/t2.micro are Free Tier eligible."
  type        = string
  default     = "t3.micro"
}

variable "my_ip" {
  description = "Your public IP in CIDR form (e.g. 1.2.3.4/32) — used to lock SSH to ONLY you. Get it with: curl ifconfig.me"
  type        = string
}

variable "allow_http_from" {
  description = "CIDR allowed to reach HTTP (port 80). 0.0.0.0/0 = public website."
  type        = string
  default     = "0.0.0.0/0"
}

variable "environments" {
  description = "The servers to create (one EC2 each)."
  type        = list(string)
  default     = ["dev","staging","prod"]
}
