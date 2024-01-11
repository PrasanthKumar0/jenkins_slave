variable "ingressrules" {
  type    = list(number)
  default = [8080, 22]
}

variable "public_key" {
  type        = string
  description = "File path of public key."
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key" {
  type        = string
  description = "File path of private key."
  default     = "~/.ssh/id_rsa"
}

variable "domainName" {
  default = "jenkins.robofarming.link"
  type    = string
}