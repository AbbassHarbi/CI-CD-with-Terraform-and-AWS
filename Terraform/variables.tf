variable "region" {
  type= string
}

variable "public_key" {
  type= string
}

variable "private_key" {
  type= string
  sensitive= true
}

variable "key_name" {
  type= string
}