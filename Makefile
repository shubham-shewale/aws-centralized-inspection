.PHONY: init plan apply destroy validate health-check routing-check

# Default environment
ENV ?= dev

# Terraform commands
init:
	cd live && terraform init

plan:
	cd live && terraform plan -var-file=../envs/$(ENV).tfvars

apply:
	cd live && terraform apply -var-file=../envs/$(ENV).tfvars

destroy:
	cd live && terraform destroy -var-file=../envs/$(ENV).tfvars

validate:
	cd live && terraform validate

fmt:
	cd live && terraform fmt -recursive

# Validation scripts
health-check:
	./validation/health-check.sh

routing-check:
	./validation/routing-check.sh

# Combined validation
validate-all: validate health-check routing-check

# Clean up
clean:
	cd live && rm -rf .terraform terraform.tfstate*

# Help
help:
	@echo "Available targets:"
	@echo "  init          - Initialize Terraform"
	@echo "  plan          - Plan Terraform changes"
	@echo "  apply         - Apply Terraform changes"
	@echo "  destroy       - Destroy Terraform resources"
	@echo "  validate      - Validate Terraform configuration"
	@echo "  fmt           - Format Terraform files"
	@echo "  health-check  - Run health checks"
	@echo "  routing-check - Run routing checks"
	@echo "  validate-all  - Run all validations"
	@echo "  clean         - Clean up Terraform files"
	@echo ""
	@echo "Environment variables:"
	@echo "  ENV           - Environment to use (default: dev)"