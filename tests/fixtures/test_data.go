package fixtures

import (
	"fmt"
	"math/rand"
	"time"
)

// TestDataManager manages test data and fixtures
type TestDataManager struct {
	Environment string
	Region      string
	Random      *rand.Rand
}

// NewTestDataManager creates a new test data manager
func NewTestDataManager(environment, region string) *TestDataManager {
	return &TestDataManager{
		Environment: environment,
		Region:      region,
		Random:      rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

// NetworkTestData contains network-related test data
type NetworkTestData struct {
	VpcCidr        string
	SpokeVpcCidrs  []string
	PublicSubnets  []string
	PrivateSubnets []string
	Azs            []string
	TgwAsn         int
}

// GetNetworkTestData returns network test data for the specified environment
func (tdm *TestDataManager) GetNetworkTestData() *NetworkTestData {
	switch tdm.Environment {
	case "dev":
		return &NetworkTestData{
			VpcCidr:        "10.0.0.0/16",
			SpokeVpcCidrs:  []string{"10.1.0.0/16"},
			PublicSubnets:  []string{"10.0.10.0/24"},
			PrivateSubnets: []string{"10.0.20.0/24"},
			Azs:            []string{"us-east-1a"},
			TgwAsn:         64512,
		}
	case "staging":
		return &NetworkTestData{
			VpcCidr:        "10.10.0.0/16",
			SpokeVpcCidrs:  []string{"10.11.0.0/16", "10.12.0.0/16"},
			PublicSubnets:  []string{"10.10.10.0/24", "10.10.11.0/24"},
			PrivateSubnets: []string{"10.10.20.0/24", "10.10.21.0/24"},
			Azs:            []string{"us-east-1a", "us-east-1b"},
			TgwAsn:         64513,
		}
	case "prod":
		return &NetworkTestData{
			VpcCidr:        "10.100.0.0/16",
			SpokeVpcCidrs:  []string{"10.101.0.0/16", "10.102.0.0/16", "10.103.0.0/16"},
			PublicSubnets:  []string{"10.100.10.0/24", "10.100.11.0/24", "10.100.12.0/24"},
			PrivateSubnets: []string{"10.100.20.0/24", "10.100.21.0/24", "10.100.22.0/24"},
			Azs:            []string{"us-east-1a", "us-east-1b", "us-east-1c"},
			TgwAsn:         64514,
		}
	default:
		return &NetworkTestData{
			VpcCidr:        "10.0.0.0/16",
			SpokeVpcCidrs:  []string{"10.1.0.0/16"},
			PublicSubnets:  []string{"10.0.10.0/24"},
			PrivateSubnets: []string{"10.0.20.0/24"},
			Azs:            []string{"us-east-1a"},
			TgwAsn:         64512,
		}
	}
}

// FirewallTestData contains firewall-related test data
type FirewallTestData struct {
	Version         string
	InstanceType    string
	MinSize         int
	MaxSize         int
	KeyName         string
	SecurityRules   []SecurityRule
	BootstrapConfig map[string]string
}

// SecurityRule represents a firewall security rule
type SecurityRule struct {
	Name                 string
	Action               string
	SourceZones          []string
	DestinationZones     []string
	SourceAddresses      []string
	DestinationAddresses []string
	Applications         []string
	Services             []string
}

// GetFirewallTestData returns firewall test data
func (tdm *TestDataManager) GetFirewallTestData() *FirewallTestData {
	return &FirewallTestData{
		Version:      "10.2.0",
		InstanceType: "m5.xlarge",
		MinSize:      2,
		MaxSize:      4,
		KeyName:      fmt.Sprintf("vmseries-key-%s", tdm.Environment),
		SecurityRules: []SecurityRule{
			{
				Name:                 "allow-web-traffic",
				Action:               "allow",
				SourceZones:          []string{"trust"},
				DestinationZones:     []string{"untrust"},
				SourceAddresses:      []string{"10.1.0.0/16"},
				DestinationAddresses: []string{"0.0.0.0/0"},
				Applications:         []string{"web-browsing", "ssl"},
				Services:             []string{"service-http", "service-https"},
			},
			{
				Name:                 "allow-ssh",
				Action:               "allow",
				SourceZones:          []string{"trust"},
				DestinationZones:     []string{"untrust"},
				SourceAddresses:      []string{"10.0.0.0/8"},
				DestinationAddresses: []string{"0.0.0.0/0"},
				Applications:         []string{"ssh"},
				Services:             []string{"application-default"},
			},
		},
		BootstrapConfig: map[string]string{
			"type":            "dhcp-client",
			"hostname":        fmt.Sprintf("vmseries-%s", tdm.Environment),
			"panorama-server": "panorama.example.com",
			"auth-key":        "your-auth-key",
			"dgname":          fmt.Sprintf("%s-dg", tdm.Environment),
			"tplname":         fmt.Sprintf("%s-template", tdm.Environment),
		},
	}
}

// MonitoringTestData contains monitoring-related test data
type MonitoringTestData struct {
	FlowLogsRetentionDays int
	LogGroups             []string
	Metrics               []string
	Alarms                []AlarmConfig
}

// AlarmConfig represents a CloudWatch alarm configuration
type AlarmConfig struct {
	Name              string
	MetricName        string
	Namespace         string
	Statistic         string
	ComparisonOp      string
	Threshold         float64
	EvaluationPeriods int
}

// GetMonitoringTestData returns monitoring test data
func (tdm *TestDataManager) GetMonitoringTestData() *MonitoringTestData {
	return &MonitoringTestData{
		FlowLogsRetentionDays: 30,
		LogGroups: []string{
			fmt.Sprintf("/aws/vpc/flow-logs/inspection-%s", tdm.Environment),
			fmt.Sprintf("/aws/vmseries/%s", tdm.Environment),
		},
		Metrics: []string{
			"ActiveFlowCount",
			"ProcessedBytes",
			"CPUUtilization",
			"MemoryUtilization",
		},
		Alarms: []AlarmConfig{
			{
				Name:              fmt.Sprintf("inspection-high-cpu-%s", tdm.Environment),
				MetricName:        "CPUUtilization",
				Namespace:         "AWS/EC2",
				Statistic:         "Average",
				ComparisonOp:      "GreaterThanThreshold",
				Threshold:         80.0,
				EvaluationPeriods: 2,
			},
			{
				Name:              fmt.Sprintf("inspection-unhealthy-targets-%s", tdm.Environment),
				MetricName:        "UnHealthyHostCount",
				Namespace:         "AWS/GatewayELB",
				Statistic:         "Maximum",
				ComparisonOp:      "GreaterThanThreshold",
				Threshold:         0.0,
				EvaluationPeriods: 1,
			},
		},
	}
}

// ComplianceTestData contains compliance-related test data
type ComplianceTestData struct {
	DataClassification   string
	EncryptionRequired   bool
	BackupRequired       bool
	Tags                 map[string]string
	ComplianceFrameworks []string
}

// GetComplianceTestData returns compliance test data
func (tdm *TestDataManager) GetComplianceTestData() *ComplianceTestData {
	return &ComplianceTestData{
		DataClassification: "sensitive",
		EncryptionRequired: true,
		BackupRequired:     true,
		Tags: map[string]string{
			"Environment":        tdm.Environment,
			"Project":            "centralized-inspection",
			"DataClassification": "sensitive",
			"EncryptionAtRest":   "required",
			"Backup":             "required",
			"Compliance":         "pci-dss,hipaa,soc2,gdpr,nist-800-53",
		},
		ComplianceFrameworks: []string{
			"PCI DSS",
			"HIPAA",
			"SOC 2",
			"GDPR",
			"NIST 800-53",
		},
	}
}

// PerformanceTestData contains performance-related test data
type PerformanceTestData struct {
	LoadTestDuration   time.Duration
	ConcurrentUsers    int
	TargetThroughput   float64
	LatencyThreshold   time.Duration
	ErrorRateThreshold float64
	TestScenarios      []TestScenario
}

// TestScenario represents a performance test scenario
type TestScenario struct {
	Name        string
	Description string
	TrafficType string
	Volume      int
	Duration    time.Duration
}

// GetPerformanceTestData returns performance test data
func (tdm *TestDataManager) GetPerformanceTestData() *PerformanceTestData {
	return &PerformanceTestData{
		LoadTestDuration:   10 * time.Minute,
		ConcurrentUsers:    100,
		TargetThroughput:   1000000000, // 1 Gbps
		LatencyThreshold:   50 * time.Millisecond,
		ErrorRateThreshold: 0.01, // 1%
		TestScenarios: []TestScenario{
			{
				Name:        "HTTP Traffic",
				Description: "Test HTTP traffic inspection performance",
				TrafficType: "http",
				Volume:      1000,
				Duration:    5 * time.Minute,
			},
			{
				Name:        "HTTPS Traffic",
				Description: "Test HTTPS traffic inspection performance",
				TrafficType: "https",
				Volume:      800,
				Duration:    5 * time.Minute,
			},
			{
				Name:        "East-West Traffic",
				Description: "Test inter-VPC traffic inspection performance",
				TrafficType: "internal",
				Volume:      500,
				Duration:    3 * time.Minute,
			},
		},
	}
}

// ChaosTestData contains chaos engineering test data
type ChaosTestData struct {
	FailureScenarios       []FailureScenario
	RecoveryTimeObjectives map[string]time.Duration
	BlastRadiusLimits      map[string]int
}

// FailureScenario represents a chaos engineering failure scenario
type FailureScenario struct {
	Name        string
	Description string
	TargetType  string
	FailureType string
	Duration    time.Duration
	Impact      string
}

// GetChaosTestData returns chaos engineering test data
func (tdm *TestDataManager) GetChaosTestData() *ChaosTestData {
	return &ChaosTestData{
		FailureScenarios: []FailureScenario{
			{
				Name:        "AZ Failure",
				Description: "Simulate complete Availability Zone failure",
				TargetType:  "infrastructure",
				FailureType: "az-outage",
				Duration:    10 * time.Minute,
				Impact:      "high",
			},
			{
				Name:        "Firewall Instance Failure",
				Description: "Terminate firewall instances to test auto-scaling",
				TargetType:  "application",
				FailureType: "instance-termination",
				Duration:    5 * time.Minute,
				Impact:      "medium",
			},
			{
				Name:        "Network Connectivity Loss",
				Description: "Simulate network connectivity issues",
				TargetType:  "network",
				FailureType: "connectivity-loss",
				Duration:    3 * time.Minute,
				Impact:      "high",
			},
		},
		RecoveryTimeObjectives: map[string]time.Duration{
			"critical": 15 * time.Minute,
			"high":     30 * time.Minute,
			"medium":   60 * time.Minute,
		},
		BlastRadiusLimits: map[string]int{
			"critical": 10,
			"high":     25,
			"medium":   50,
		},
	}
}

// CostTestData contains cost optimization test data
type CostTestData struct {
	BudgetAmount                float64
	AlertThreshold              float64
	ReservedInstanceUtilization float64
	SpotInstanceSavings         float64
	ResourceTags                map[string]string
}

// GetCostTestData returns cost optimization test data
func (tdm *TestDataManager) GetCostTestData() *CostTestData {
	return &CostTestData{
		BudgetAmount:                1000.0,
		AlertThreshold:              80.0,
		ReservedInstanceUtilization: 85.0,
		SpotInstanceSavings:         70.0,
		ResourceTags: map[string]string{
			"Environment":      tdm.Environment,
			"Project":          "centralized-inspection",
			"CostCenter":       "security-operations",
			"Owner":            "cost-optimization-team",
			"AutoShutdown":     "enabled",
			"ReservedInstance": "eligible",
			"SpotInstance":     "eligible",
		},
	}
}

// GenerateRandomString generates a random string of specified length
func (tdm *TestDataManager) GenerateRandomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	result := make([]byte, length)
	for i := range result {
		result[i] = charset[tdm.Random.Intn(len(charset))]
	}
	return string(result)
}

// GenerateRandomIP generates a random IP address
func (tdm *TestDataManager) GenerateRandomIP() string {
	return fmt.Sprintf("%d.%d.%d.%d",
		tdm.Random.Intn(256),
		tdm.Random.Intn(256),
		tdm.Random.Intn(256),
		tdm.Random.Intn(256))
}

// GenerateRandomCIDR generates a random CIDR block
func (tdm *TestDataManager) GenerateRandomCIDR(prefix int) string {
	return fmt.Sprintf("%s/%d", tdm.GenerateRandomIP(), prefix)
}

// GetTestDataSummary returns a summary of all test data
func (tdm *TestDataManager) GetTestDataSummary() map[string]interface{} {
	return map[string]interface{}{
		"environment": tdm.Environment,
		"region":      tdm.Region,
		"network":     tdm.GetNetworkTestData(),
		"firewall":    tdm.GetFirewallTestData(),
		"monitoring":  tdm.GetMonitoringTestData(),
		"compliance":  tdm.GetComplianceTestData(),
		"performance": tdm.GetPerformanceTestData(),
		"chaos":       tdm.GetChaosTestData(),
		"cost":        tdm.GetCostTestData(),
	}
}
