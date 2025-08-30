# AWS Centralized Inspection - Comprehensive Test Suite

This directory contains a comprehensive, production-grade test suite for the AWS centralized traffic inspection architecture using Palo Alto Networks VM-Series firewalls.

## 🏗️ Test Architecture

### Test Categories

| Category | Description | Location | Framework |
|----------|-------------|----------|-----------|
| **Unit Tests** | Individual module validation | `network/`, `inspection/`, `firewall-vmseries/` | Terratest |
| **Integration Tests** | End-to-end infrastructure validation | `integration/` | Terratest |
| **Compliance Tests** | Security and regulatory compliance | `compliance/` | Terratest |
| **Performance Tests** | Load and performance validation | `performance/` | Terratest |
| **Chaos Tests** | Resiliency and failure simulation | `chaos/` | Terratest |
| **Cost Tests** | Cost optimization validation | `cost/` | Terratest |
| **Security Tests** | Static security analysis | N/A | tfsec |
| **Validation Scripts** | Infrastructure validation | `validation/` | Bash |

### Test Framework Stack

- **Primary Framework**: [Terratest](https://terratest.gruntwork.io/) (Go-based infrastructure testing)
- **Static Analysis**: [tfsec](https://aquasecurity.github.io/tfsec/) (Infrastructure as Code security scanning)
- **CI/CD Integration**: GitHub Actions with matrix testing
- **Reporting**: Custom analytics and reporting system
- **Test Data**: Structured fixtures and data management

## 🚀 Quick Start

### Prerequisites

```bash
# Install Go (1.21+)
curl -LO https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz

# Install Terraform (1.5.0+)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install tfsec (optional, for security scanning)
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/install.sh | sh
```

### Setup and Execution

```bash
# Navigate to tests directory
cd tests

# Setup test environment
make setup

# Install dependencies
make deps

# Run all tests
make test-all

# Run specific test categories
make test-unit          # Unit tests only
make test-integration   # Integration tests only
make test-security      # Security tests (tfsec)
make test-performance   # Performance tests

# Run tests with coverage
make test-coverage

# Generate test reports
make report
```

### Environment Configuration

```bash
# Set environment variables
export ENVIRONMENT=test
export REGION=us-east-1
export AWS_PROFILE=your-profile

# Or create .env file
cat > .env << EOF
ENVIRONMENT=test
REGION=us-east-1
AWS_PROFILE=your-profile
TF_VAR_panos_hostname=panorama.example.com
TF_VAR_panos_username=admin
EOF
```

## 📊 Test Categories

### 1. Unit Tests

**Purpose**: Validate individual Terraform modules and their configurations.

**Location**: `network/`, `inspection/`, `firewall-vmseries/`

**Coverage**:
- Resource creation and configuration
- Variable validation
- Output validation
- Error handling

**Example**:
```bash
# Run network unit tests
cd network && go test -v ./...

# Run inspection unit tests
cd inspection && go test -v ./...
```

### 2. Integration Tests

**Purpose**: Validate complete infrastructure deployment and interactions.

**Location**: `integration/`

**Coverage**:
- End-to-end infrastructure provisioning
- Cross-module dependencies
- Traffic flow validation
- Resource connectivity

**Example**:
```bash
# Run integration tests
cd integration && go test -v -run TestEndToEndTrafficInspection ./...
```

### 3. Compliance Tests

**Purpose**: Ensure infrastructure meets security and regulatory requirements.

**Location**: `compliance/`

**Coverage**:
- PCI DSS compliance
- HIPAA compliance
- SOC 2 compliance
- NIST 800-53 compliance
- GDPR compliance

**Example**:
```bash
# Run compliance tests
cd compliance && go test -v -run TestPCIDSSCompliance ./...
```

### 4. Performance Tests

**Purpose**: Validate system performance under various loads.

**Location**: `performance/`

**Coverage**:
- GWLB throughput and latency
- Firewall performance
- Auto-scaling behavior
- Resource utilization

**Example**:
```bash
# Run performance tests
cd performance && go test -v -run TestGWLBPerformance ./...
```

### 5. Chaos Engineering Tests

**Purpose**: Test system resiliency under failure conditions.

**Location**: `chaos/`

**Coverage**:
- AZ failure scenarios
- Instance failure scenarios
- Network failure scenarios
- Recovery mechanisms

**Example**:
```bash
# Run chaos tests
cd chaos && go test -v -run TestAZFailureResiliency ./...
```

### 6. Cost Optimization Tests

**Purpose**: Validate cost optimization measures and controls.

**Location**: `cost/`

**Coverage**:
- Resource right-sizing
- Reserved instance utilization
- Spot instance optimization
- Budget monitoring

**Example**:
```bash
# Run cost optimization tests
cd cost && go test -v -run TestCostOptimizationValidation ./...
```

### 7. Security Scanning

**Purpose**: Static analysis of infrastructure code for security issues.

**Framework**: tfsec

**Coverage**:
- CIS AWS Foundations compliance
- Encryption validation
- Access control validation
- Network security validation

**Example**:
```bash
# Run security scan
make test-tfsec

# Generate security audit report
make audit
```

## 🔧 Test Configuration

### Test Environments

| Environment | Purpose | Resources | Duration |
|-------------|---------|-----------|----------|
| **dev** | Fast feedback during development | Minimal | < 15 min |
| **staging** | Pre-production validation | Complete | < 45 min |
| **prod** | Final validation | Production-scale | < 60 min |

### Test Data Management

**Location**: `fixtures/`

**Features**:
- Environment-specific test data
- Randomized test data generation
- Structured data models
- Reusable test fixtures

**Example**:
```go
// Create test data manager
tdm := fixtures.NewTestDataManager("test", "us-east-1")

// Get network test data
networkData := tdm.GetNetworkTestData()

// Get firewall test data
firewallData := tdm.GetFirewallTestData()
```

### Validation Scripts

**Location**: `validation/`

**Scripts**:
- `comprehensive_validation.sh`: Complete infrastructure validation
- Health checks and connectivity tests
- Configuration validation
- Security posture validation

**Example**:
```bash
# Run comprehensive validation
./validation/comprehensive_validation.sh

# Validate specific components
ENVIRONMENT=test REGION=us-east-1 ./validation/comprehensive_validation.sh
```

## 📈 Reporting and Analytics

### Test Reports

**Location**: `reporting/`

**Formats**:
- JSON: Machine-readable format
- HTML: Interactive web reports
- Markdown: Documentation-friendly
- JUnit XML: CI/CD integration

**Example**:
```go
// Create analytics instance
analytics := reporting.NewTestAnalytics()

// Add test results
analytics.AddResult(testSuiteResult)

// Generate reports
jsonReport, _ := analytics.GenerateReport("json")
htmlReport, _ := analytics.GenerateReport("html")

// Export to files
analytics.ExportResults("test-report", "html")
```

### Metrics and Trends

**Features**:
- Pass/fail rates over time
- Performance trends
- Test execution times
- Coverage analysis
- Failure pattern analysis

**Example**:
```go
// Get aggregated metrics
metrics := analytics.GetMetrics()

// Get trend analysis
trends := analytics.GetTrendAnalysis()

// Get failed tests
failedTests := analytics.GetFailedTests()
```

## 🔒 Security Testing

### Static Security Analysis

```bash
# Run tfsec on modules
tfsec --config-file .tfsec.yml ../modules/

# Generate security audit report
tfsec --config-file .tfsec.yml --format json ../modules/ > security-audit.json
```

### Compliance Validation

```bash
# Run compliance tests
cd compliance && go test -v ./...

# Validate specific compliance frameworks
go test -v -run TestPCIDSSCompliance ./...
go test -v -run TestHIPAACompliance ./...
go test -v -run TestSOC2Compliance ./...
```

### Automated Remediation Testing

```bash
# Run remediation tests
cd remediation && go test -v ./...

# Test specific remediation scenarios
go test -v -run TestSecurityGroupRemediation ./...
go test -v -run TestInstanceQuarantine ./...
```

## ⚡ Performance Testing

### Load Testing

```bash
# Run performance tests
cd performance && go test -v ./...

# Test specific performance scenarios
go test -v -run TestGWLBPerformance ./...
go test -v -run TestFirewallPerformance ./...
```

### Benchmarking

```bash
# Run benchmark tests
go test -bench=. -benchmem ./...

# Profile performance
go test -cpuprofile=cpu.prof -bench=. ./...
go tool pprof cpu.prof
```

## 🧪 Chaos Engineering

### Failure Simulation

```bash
# Run chaos tests
cd chaos && go test -v ./...

# Test specific failure scenarios
go test -v -run TestAZFailureResiliency ./...
go test -v -run TestFirewallInstanceFailure ./...
```

### Recovery Testing

```bash
# Test recovery mechanisms
go test -v -run TestAZRecovery ./...
go test -v -run TestInstanceRecovery ./...
```

## 💰 Cost Optimization

### Cost Validation

```bash
# Run cost optimization tests
cd cost && go test -v ./...

# Test specific cost scenarios
go test -v -run TestSpotInstanceOptimization ./...
go test -v -run TestStorageOptimization ./...
```

### Budget Monitoring

```bash
# Test budget and alerting
go test -v -run TestBudgetAndAlerting ./...
```

## 🔄 CI/CD Integration

### GitHub Actions

```yaml
name: Test Suite
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        go-version: [1.21.x]
        terraform-version: [1.5.0]
        region: [us-east-1, us-west-2]
        environment: [dev, staging]

    steps:
    - uses: actions/checkout@v3

    - name: Set up Go
      uses: actions/setup-go@v4
      with:
        go-version: ${{ matrix.go-version }}

    - name: Set up Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ matrix.terraform-version }}

    - name: Configure AWS
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ matrix.region }}

    - name: Run tests
      run: |
        cd tests
        make setup
        make deps
        ENVIRONMENT=${{ matrix.environment }} REGION=${{ matrix.region }} make test-all

    - name: Generate reports
      run: |
        cd tests
        make report

    - name: Upload test results
      uses: actions/upload-artifact@v3
      with:
        name: test-results-${{ matrix.environment }}-${{ matrix.region }}
        path: tests/test-reports/
```

### Makefile Targets

```bash
# Development workflow
make setup          # Setup test environment
make deps           # Install dependencies
make test-unit      # Run unit tests
make test-integration # Run integration tests
make test-all       # Run all tests
make test-coverage  # Run tests with coverage
make report         # Generate test reports

# CI/CD workflow
make ci-test        # CI test execution
make validate       # Code validation
make lint           # Code linting
make pre-commit     # Pre-commit checks

# Specialized testing
make test-security  # Security tests
make test-performance # Performance tests
make perf-test      # Benchmark tests
make load-test      # Load testing
make chaos-test     # Chaos engineering
```

## 📋 Test Data and Fixtures

### Structured Test Data

**Location**: `fixtures/test_data.go`

**Features**:
- Environment-specific configurations
- Randomized data generation
- Structured data models
- Reusable across test categories

### Test Isolation

- **Resource Naming**: Unique prefixes per test run
- **VPC Isolation**: Dedicated VPCs for each test
- **IAM Isolation**: Test-specific roles and policies
- **Cleanup**: Automatic resource cleanup

## 🎯 Best Practices

### Test Organization

1. **Categorize Tests**: Group tests by functionality and risk level
2. **Parallel Execution**: Design tests to run in parallel
3. **Resource Cleanup**: Ensure proper cleanup after test execution
4. **Idempotent Tests**: Tests should produce consistent results

### Test Data Management

1. **Structured Fixtures**: Use structured test data management
2. **Environment Awareness**: Different data for different environments
3. **Randomization**: Use randomization to avoid test interference
4. **Version Control**: Keep test data under version control

### CI/CD Integration

1. **Matrix Testing**: Test across multiple environments and regions
2. **Parallel Jobs**: Run tests in parallel for faster feedback
3. **Artifact Management**: Store test results and reports
4. **Notification**: Alert on test failures

### Monitoring and Alerting

1. **Test Metrics**: Track test execution time and success rates
2. **Performance Trends**: Monitor performance over time
3. **Failure Analysis**: Analyze patterns in test failures
4. **Reporting**: Generate comprehensive test reports

## 🚨 Troubleshooting

### Common Issues

#### Test Timeouts
```bash
# Increase timeout
go test -timeout 30m ./...

# Run tests individually
go test -v -run TestSpecificTest ./...
```

#### AWS API Limits
```bash
# Add delays between tests
time.Sleep(5 * time.Second)

# Use different regions
export AWS_REGION=us-west-2
```

#### Resource Conflicts
```bash
# Use unique resource names
resourceName := fmt.Sprintf("test-%s-%d", t.Name(), time.Now().Unix())

# Clean up resources
defer terraform.Destroy(t, terraformOptions)
```

#### Dependency Issues
```bash
# Rebuild dependencies
make clean
make deps

# Update Go modules
go mod tidy
go mod download
```

### Debug Mode

```bash
# Enable debug logging
export TF_LOG=DEBUG

# Run tests with verbose output
go test -v ./...

# Check AWS API calls
aws cloudtrail lookup-events --max-items 10
```

## 📊 Success Metrics

### Test Quality Metrics

- **Coverage**: > 90% infrastructure coverage
- **Reliability**: > 95% test success rate
- **Performance**: < 60 minutes total execution time
- **Security**: Zero high-severity security issues

### Business Value Metrics

- **Deployment Confidence**: Reduced production incidents
- **Time to Market**: Faster feature deployment
- **Cost Efficiency**: Optimized infrastructure costs
- **Compliance**: 100% compliance with security standards

## 🔗 Related Documentation

- [Architecture Documentation](../ARCHITECTURE.md)
- [Deployment Guide](../DEPLOYMENT_GUIDE.md)
- [Security Guide](../SECURITY.md)
- [Troubleshooting Guide](../TROUBLESHOOTING.md)

## 🤝 Contributing

### Adding New Tests

1. **Choose Test Category**: Determine appropriate test category
2. **Follow Naming Convention**: Use descriptive test names
3. **Add Documentation**: Document test purpose and coverage
4. **Update CI/CD**: Ensure tests run in CI/CD pipeline

### Test Development Workflow

1. **Write Test**: Implement test using Terratest framework
2. **Add Fixtures**: Create necessary test data and fixtures
3. **Run Locally**: Test execution in local environment
4. **Add to CI/CD**: Include in automated test pipeline
5. **Document**: Update test documentation

---

This comprehensive test suite ensures the AWS centralized inspection architecture is thoroughly validated across all aspects of functionality, performance, security, and compliance. Regular execution and maintenance of these tests is crucial for maintaining infrastructure quality and reliability.