variable "sourceURL" {
  type        = string
  description = "The url (without http(s):// prefix) that will be serving the 301."
  default     = "nathangramer.com"
}
variable "targetURL" {
  type        = string
  description = "The target URL (including http(s)://) that the 301 will point to."
  default     = "https://nategramer.com"
}
