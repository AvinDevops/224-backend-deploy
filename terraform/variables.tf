variable "project_name" {
    default = "expense"
}

variable "environment" {
    default = "dev"
}

variable "common_tags" {
    default = {
        Project = "Expense"
        Environment = "Dev"
        Terraform = "True"
        Component = "backend"
    }
}

variable "zone_name" {
    default = "aviexpense.online"
}

variable "app_version" {
    
}