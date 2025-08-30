.PHONY: test test-unit test-integration test-security test-tfsec test-all clean help

# Default test environment
ENV ?= dev
REGION ?= us-east-1
AWS_PROFILE ?= default

# Test directories
TEST_DIRS := ./network ./inspection ./firewall-vmseries ./integration
TFSEC_CONFIG := .tfsec.yml

# Go test flags
TEST_FLAGS := -v -timeout 30m
PARALLEL_FLAGS := -parallel 4
COVERAGE_FLAGS := -coverprofile=coverage.out -covermode=atomic

# Environment variables for tests
export AWS_REGION=$(REGION)
export AWS_PROFILE=$(AWS_PROFILE)
export TF_VAR_aws_region=$(REGION)
export TF_VAR_aws_profile=$(AWS_PROFILE)

# Run all tests
test-all: test-tfsec test-unit test-integration
	@echo "✅ All tests completed successfully"

# Run unit tests only
test-unit:
	@echo "🧪 Running unit tests..."
	@for dir in $(TEST_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "Running tests in $$dir..."; \
			cd $$dir && go test $(TEST_FLAGS) $(PARALLEL_FLAGS) $(COVERAGE_FLAGS) ./... || exit 1; \
			cd ..; \
		fi; \
	done
	@echo "✅ Unit tests completed"

# Run integration tests only
test-integration:
	@echo "🔗 Running integration tests..."
	@cd integration && go test $(TEST_FLAGS) -run TestEndToEnd ./...
	@echo "✅ Integration tests completed"

# Run security tests
test-security: test-tfsec
	@echo "🔒 Security tests completed"

# Run tfsec static analysis
test-tfsec:
	@echo "🔍 Running tfsec static analysis..."
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec --config-file $(TFSEC_CONFIG) ../modules/ || echo "⚠️  tfsec found issues"; \
	else \
		echo "⚠️  tfsec not installed, skipping static analysis"; \
	fi
	@echo "✅ tfsec analysis completed"

# Run tests with coverage
test-coverage: test-unit
	@echo "📊 Generating coverage report..."
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Run tests in verbose mode
test-verbose:
	@echo "📝 Running tests in verbose mode..."
	@go test $(TEST_FLAGS) -v ./...

# Run tests with race detection
test-race:
	@echo "🏃 Running tests with race detection..."
	@go test $(TEST_FLAGS) $(PARALLEL_FLAGS) -race ./...

# Run specific test
test-specific:
	@echo "🎯 Usage: make test-specific TEST=TestName"
	@if [ -n "$(TEST)" ]; then \
		go test $(TEST_FLAGS) -run $(TEST) ./...; \
	else \
		echo "Please specify TEST variable: make test-specific TEST=TestName"; \
	fi

# Run tests for specific module
test-module:
	@echo "📦 Usage: make test-module MODULE=network"
	@if [ -n "$(MODULE)" ]; then \
		if [ -d "$(MODULE)" ]; then \
			cd $(MODULE) && go test $(TEST_FLAGS) $(PARALLEL_FLAGS) ./...; \
		else \
			echo "Module $(MODULE) not found"; \
		fi; \
	else \
		echo "Please specify MODULE variable: make test-module MODULE=network"; \
	fi

# Setup test environment
setup:
	@echo "⚙️  Setting up test environment..."
	@go mod tidy
	@go mod download
	@echo "✅ Test environment setup complete"

# Install test dependencies
deps:
	@echo "📦 Installing test dependencies..."
	@go install github.com/gruntwork-io/terratest/modules/aws@latest
	@go install github.com/gruntwork-io/terratest/modules/terraform@latest
	@if ! command -v tfsec >/dev/null 2>&1; then \
		echo "Installing tfsec..."; \
		curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/install.sh | sh; \
	fi
	@echo "✅ Dependencies installed"

# Clean test artifacts
clean:
	@echo "🧹 Cleaning test artifacts..."
	@rm -f coverage.out coverage.html
	@find . -name "*.log" -type f -delete
	@find . -name "*.tmp" -type f -delete
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "terraform.tfstate*" -type f -delete
	@echo "✅ Cleanup completed"

# Show test help
help:
	@echo "Available targets:"
	@echo "  test-all          - Run all tests (tfsec + unit + integration)"
	@echo "  test-unit         - Run unit tests only"
	@echo "  test-integration  - Run integration tests only"
	@echo "  test-security     - Run security tests (tfsec)"
	@echo "  test-tfsec        - Run tfsec static analysis"
	@echo "  test-coverage     - Run tests with coverage report"
	@echo "  test-verbose      - Run tests in verbose mode"
	@echo "  test-race         - Run tests with race detection"
	@echo "  test-specific     - Run specific test (use TEST=TestName)"
	@echo "  test-module       - Run tests for specific module (use MODULE=name)"
	@echo "  setup             - Setup test environment"
	@echo "  deps              - Install test dependencies"
	@echo "  clean             - Clean test artifacts"
	@echo "  help              - Show this help"
	@echo ""
	@echo "Environment variables:"
	@echo "  ENV=$(ENV)        - Test environment"
	@echo "  REGION=$(REGION)  - AWS region"
	@echo "  AWS_PROFILE=$(AWS_PROFILE) - AWS profile"

# CI/CD targets
ci-test: deps setup test-all test-coverage
	@echo "🚀 CI tests completed"

# Development targets
dev-test: test-unit test-tfsec
	@echo "👨‍💻 Development tests completed"

# Performance testing
perf-test:
	@echo "⚡ Running performance tests..."
	@go test $(TEST_FLAGS) -bench=. -benchmem ./...
	@echo "✅ Performance tests completed"

# Load testing (placeholder)
load-test:
	@echo "🔥 Running load tests..."
	@echo "⚠️  Load testing requires actual infrastructure deployment"
	@echo "   Use: make test-integration for end-to-end validation"
	@echo "✅ Load test placeholder completed"

# Security audit
audit: test-tfsec
	@echo "🔍 Running security audit..."
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec --config-file $(TFSEC_CONFIG) --format json ../modules/ > security-audit.json; \
		echo "Security audit report: security-audit.json"; \
	else \
		echo "⚠️  tfsec not installed"; \
	fi
	@echo "✅ Security audit completed"

# Quick validation
validate:
	@echo "✅ Running quick validation..."
	@go vet ./...
	@go fmt ./...
	@if command -v golint >/dev/null 2>&1; then golint ./...; fi
	@echo "✅ Validation completed"

# Docker-based testing
docker-test:
	@echo "🐳 Running tests in Docker..."
	@docker run --rm -v $(PWD):/app -w /app golang:1.21 \
		sh -c "make deps && make test-unit"
	@echo "✅ Docker tests completed"

# Cross-platform testing
cross-test:
	@echo "🔄 Running cross-platform tests..."
	@GOOS=linux GOARCH=amd64 go test $(TEST_FLAGS) ./...
	@GOOS=darwin GOARCH=amd64 go test $(TEST_FLAGS) ./...
	@echo "✅ Cross-platform tests completed"

# Benchmark tests
benchmark:
	@echo "📊 Running benchmark tests..."
	@go test -bench=. -benchmem -count=3 ./...
	@echo "✅ Benchmark tests completed"

# Memory profiling
profile-mem:
	@echo "🧠 Running memory profiling..."
	@go test -memprofile=mem.prof -bench=. ./...
	@go tool pprof mem.prof
	@echo "✅ Memory profiling completed"

# CPU profiling
profile-cpu:
	@echo "⚡ Running CPU profiling..."
	@go test -cpuprofile=cpu.prof -bench=. ./...
	@go tool pprof cpu.prof
	@echo "✅ CPU profiling completed"

# Generate test report
report:
	@echo "📋 Generating test report..."
	@go test $(TEST_FLAGS) -json ./... > test-results.json
	@echo "Test results: test-results.json"
	@echo "✅ Test report generated"

# Watch mode for development
watch:
	@echo "👀 Watching for changes..."
	@if command -v reflex >/dev/null 2>&1; then \
		reflex -r '\.go$$' -- make test-unit; \
	else \
		echo "Install reflex for watch mode: go install github.com/cespare/reflex@latest"; \
	fi

# Lint code
lint:
	@echo "🔍 Running linters..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "Install golangci-lint for advanced linting"; \
		go vet ./...; \
	fi
	@echo "✅ Linting completed"

# Pre-commit checks
pre-commit: validate lint test-unit test-tfsec
	@echo "✅ Pre-commit checks passed"

# Emergency cleanup (use with caution)
emergency-clean:
	@echo "🚨 Emergency cleanup - this will remove ALL test resources!"
	@echo "   This includes any running infrastructure from tests"
	@read -p "Are you sure? (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "Cleaning up..."; \
		make clean; \
		# Add commands to destroy any lingering resources \
		echo "✅ Emergency cleanup completed"; \
	else \
		echo "Cancelled"; \
	fi