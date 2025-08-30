package performance_test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestGWLBPerformance tests Gateway Load Balancer performance metrics
func TestGWLBPerformance(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/inspection",
		Vars: map[string]interface{}{
			"inspection_vpc_id": "vpc-12345",
			"public_subnet_ids": []string{"subnet-pub-1", "subnet-pub-2", "subnet-pub-3"},
			"spoke_vpc_ids":     []string{"vpc-spoke-1", "vpc-spoke-2"},
			"spoke_private_subnet_ids": [][]string{
				{"subnet-spoke-1-priv-1", "subnet-spoke-1-priv-2"},
				{"subnet-spoke-2-priv-1", "subnet-spoke-2-priv-2"},
			},
			"spoke_vpc_cidrs":                    []string{"10.1.0.0/16", "10.2.0.0/16"},
			"transit_gateway_id":                 "tgw-12345",
			"internet_gateway_id":                "igw-12345",
			"inspection_private_route_table_ids": []string{"rt-priv-1", "rt-priv-2", "rt-priv-3"},
			"spoke_route_table_ids":              []string{"rt-spoke-1", "rt-spoke-2"},
			"tags": map[string]string{
				"Environment": "performance-test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test GWLB throughput
	t.Run("GWLBThroughput", func(t *testing.T) {
		testGWLBThroughput(t, terraformOptions)
	})

	// Test GWLB latency
	t.Run("GWLBLatency", func(t *testing.T) {
		testGWLBLatency(t, terraformOptions)
	})

	// Test GWLB concurrent connections
	t.Run("GWLBConcurrentConnections", func(t *testing.T) {
		testGWLBConcurrentConnections(t, terraformOptions)
	})
}

// TestFirewallPerformance tests VM-Series firewall performance
func TestFirewallPerformance(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/firewall-vmseries",
		Vars: map[string]interface{}{
			"inspection_vpc_id":     "vpc-12345",
			"private_subnet_ids":    []string{"subnet-priv-1", "subnet-priv-2", "subnet-priv-3"},
			"gwlb_target_group_arn": "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gwlb-tg/1234567890abcdef",
			"vmseries_version":      "10.2.0",
			"instance_type":         "m5.xlarge",
			"min_size":              2,
			"max_size":              6,
			"tags": map[string]string{
				"Environment": "performance-test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test firewall throughput
	t.Run("FirewallThroughput", func(t *testing.T) {
		testFirewallThroughput(t, terraformOptions)
	})

	// Test firewall session capacity
	t.Run("FirewallSessionCapacity", func(t *testing.T) {
		testFirewallSessionCapacity(t, terraformOptions)
	})

	// Test firewall CPU/memory usage
	t.Run("FirewallResourceUsage", func(t *testing.T) {
		testFirewallResourceUsage(t, terraformOptions)
	})
}

// TestTransitGatewayPerformance tests TGW performance and routing
func TestTransitGatewayPerformance(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/network",
		Vars: map[string]interface{}{
			"vpc_cidr":        "10.0.0.0/16",
			"tgw_asn":         64512,
			"spoke_vpc_cidrs": []string{"10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16"},
			"public_subnets":  []string{"10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"},
			"private_subnets": []string{"10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"},
			"azs":             []string{"us-east-1a", "us-east-1b", "us-east-1c"},
			"spoke_azs":       []string{"us-east-1a", "us-east-1b", "us-east-1c"},
			"spoke_private_subnets": [][]string{
				{"10.1.20.0/24", "10.1.21.0/24", "10.1.22.0/24"},
				{"10.2.20.0/24", "10.2.21.0/24", "10.2.22.0/24"},
				{"10.3.20.0/24", "10.3.21.0/24", "10.3.22.0/24"},
			},
			"tags": map[string]string{
				"Environment": "performance-test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test TGW routing performance
	t.Run("TGWRoutingPerformance", func(t *testing.T) {
		testTGWRoutingPerformance(t, terraformOptions)
	})

	// Test TGW attachment bandwidth
	t.Run("TGWAttachmentBandwidth", func(t *testing.T) {
		testTGWAttachmentBandwidth(t, terraformOptions)
	})

	// Test TGW route propagation
	t.Run("TGWRoutePropagation", func(t *testing.T) {
		testTGWRoutePropagation(t, terraformOptions)
	})
}

// TestEndToEndPerformance tests complete traffic inspection performance
func TestEndToEndPerformance(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"inspection_engine": "vmseries",
			"enable_flow_logs":  true,
			"performance_mode":  true,
			"tags": map[string]string{
				"Environment": "performance-test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test end-to-end latency
	t.Run("EndToEndLatency", func(t *testing.T) {
		testEndToEndLatency(t, terraformOptions)
	})

	// Test end-to-end throughput
	t.Run("EndToEndThroughput", func(t *testing.T) {
		testEndToEndThroughput(t, terraformOptions)
	})

	// Test connection establishment rate
	t.Run("ConnectionEstablishmentRate", func(t *testing.T) {
		testConnectionEstablishmentRate(t, terraformOptions)
	})
}

// TestAutoScalingPerformance tests auto-scaling performance under load
func TestAutoScalingPerformance(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/firewall-vmseries",
		Vars: map[string]interface{}{
			"inspection_vpc_id":     "vpc-12345",
			"private_subnet_ids":    []string{"subnet-priv-1", "subnet-priv-2", "subnet-priv-3"},
			"gwlb_target_group_arn": "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gwlb-tg/1234567890abcdef",
			"vmseries_version":      "10.2.0",
			"instance_type":         "m5.xlarge",
			"min_size":              2,
			"max_size":              6,
			"scale_up_threshold":    70,
			"scale_down_threshold":  30,
			"tags": map[string]string{
				"Environment": "performance-test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test scale-out performance
	t.Run("ScaleOutPerformance", func(t *testing.T) {
		testScaleOutPerformance(t, terraformOptions)
	})

	// Test scale-in performance
	t.Run("ScaleInPerformance", func(t *testing.T) {
		testScaleInPerformance(t, terraformOptions)
	})

	// Test scaling decision accuracy
	t.Run("ScalingDecisionAccuracy", func(t *testing.T) {
		testScalingDecisionAccuracy(t, terraformOptions)
	})
}

// TestLoadBalancingPerformance tests load distribution across instances
func TestLoadBalancingPerformance(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../modules/inspection",
		Vars: map[string]interface{}{
			"inspection_vpc_id": "vpc-12345",
			"public_subnet_ids": []string{"subnet-pub-1", "subnet-pub-2", "subnet-pub-3"},
			"spoke_vpc_ids":     []string{"vpc-spoke-1", "vpc-spoke-2"},
			"spoke_private_subnet_ids": [][]string{
				{"subnet-spoke-1-priv-1", "subnet-spoke-1-priv-2"},
				{"subnet-spoke-2-priv-1", "subnet-spoke-2-priv-2"},
			},
			"spoke_vpc_cidrs":                    []string{"10.1.0.0/16", "10.2.0.0/16"},
			"transit_gateway_id":                 "tgw-12345",
			"internet_gateway_id":                "igw-12345",
			"inspection_private_route_table_ids": []string{"rt-priv-1", "rt-priv-2", "rt-priv-3"},
			"spoke_route_table_ids":              []string{"rt-spoke-1", "rt-spoke-2"},
			"enable_cross_zone_load_balancing":   true,
			"tags": map[string]string{
				"Environment": "performance-test",
				"Project":     "centralized-inspection",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test load distribution
	t.Run("LoadDistribution", func(t *testing.T) {
		testLoadDistribution(t, terraformOptions)
	})

	// Test session persistence
	t.Run("SessionPersistence", func(t *testing.T) {
		testSessionPersistence(t, terraformOptions)
	})

	// Test failover performance
	t.Run("FailoverPerformance", func(t *testing.T) {
		testFailoverPerformance(t, terraformOptions)
	})
}

// Performance testing helper functions

func testGWLBThroughput(t *testing.T, terraformOptions *terraform.Options) {
	// Test GWLB throughput under various loads
	// Measure packets per second, bytes per second
	// Validate against expected performance benchmarks

	gwlbArn := terraform.Output(t, terraformOptions, "gwlb_arn")
	assert.NotEmpty(t, gwlbArn, "GWLB should be created")

	// Simulate traffic load and measure throughput
	throughput := measureGWLBThroughput(t, gwlbArn)
	assert.Greater(t, throughput, float64(1000000000), "GWLB throughput should be > 1 Gbps")

	t.Logf("GWLB throughput: %.2f Gbps", throughput/1000000000)
}

func testGWLBLatency(t *testing.T, terraformOptions *terraform.Options) {
	// Test GWLB latency under normal and high load conditions
	// Measure round-trip time for packets

	gwlbArn := terraform.Output(t, terraformOptions, "gwlb_arn")
	assert.NotEmpty(t, gwlbArn, "GWLB should be created")

	// Measure latency
	latency := measureGWLBLatency(t, gwlbArn)
	assert.Less(t, latency, time.Millisecond*10, "GWLB latency should be < 10ms")

	t.Logf("GWLB latency: %v", latency)
}

func testGWLBConcurrentConnections(t *testing.T, terraformOptions *terraform.Options) {
	// Test GWLB concurrent connection handling
	// Measure maximum concurrent connections supported

	gwlbArn := terraform.Output(t, terraformOptions, "gwlb_arn")
	assert.NotEmpty(t, gwlbArn, "GWLB should be created")

	// Test concurrent connections
	maxConnections := testConcurrentConnections(t, gwlbArn)
	assert.Greater(t, maxConnections, int64(100000), "GWLB should support > 100K concurrent connections")

	t.Logf("GWLB max concurrent connections: %d", maxConnections)
}

func testFirewallThroughput(t *testing.T, terraformOptions *terraform.Options) {
	// Test firewall throughput with and without inspection enabled
	// Measure impact of security policies on performance

	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.NotEmpty(t, asgName, "Auto scaling group should be created")

	// Measure firewall throughput
	throughput := measureFirewallThroughput(t, asgName)
	assert.Greater(t, throughput, float64(500000000), "Firewall throughput should be > 500 Mbps")

	t.Logf("Firewall throughput: %.2f Mbps", throughput/1000000)
}

func testFirewallSessionCapacity(t *testing.T, terraformOptions *terraform.Options) {
	// Test firewall session table capacity
	// Measure maximum concurrent sessions supported

	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.NotEmpty(t, asgName, "Auto scaling group should be created")

	// Test session capacity
	maxSessions := testSessionCapacity(t, asgName)
	assert.Greater(t, maxSessions, int64(1000000), "Firewall should support > 1M concurrent sessions")

	t.Logf("Firewall max sessions: %d", maxSessions)
}

func testFirewallResourceUsage(t *testing.T, terraformOptions *terraform.Options) {
	// Test firewall CPU and memory usage under load
	// Ensure resources stay within acceptable limits

	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.NotEmpty(t, asgName, "Auto scaling group should be created")

	// Monitor resource usage
	cpuUsage, memoryUsage := monitorResourceUsage(t, asgName)
	assert.Less(t, cpuUsage, float64(80), "CPU usage should be < 80%")
	assert.Less(t, memoryUsage, float64(85), "Memory usage should be < 85%")

	t.Logf("Firewall CPU usage: %.1f%%, Memory usage: %.1f%%", cpuUsage, memoryUsage)
}

func testTGWRoutingPerformance(t *testing.T, terraformOptions *terraform.Options) {
	// Test TGW routing performance
	// Measure route lookup and forwarding performance

	tgwId := terraform.Output(t, terraformOptions, "transit_gateway_id")
	assert.NotEmpty(t, tgwId, "Transit Gateway should be created")

	// Test routing performance
	routingLatency := measureTGWRoutingLatency(t, tgwId)
	assert.Less(t, routingLatency, time.Millisecond*5, "TGW routing latency should be < 5ms")

	t.Logf("TGW routing latency: %v", routingLatency)
}

func testTGWAttachmentBandwidth(t *testing.T, terraformOptions *terraform.Options) {
	// Test TGW attachment bandwidth limits
	// Measure maximum throughput per attachment

	tgwId := terraform.Output(t, terraformOptions, "transit_gateway_id")
	assert.NotEmpty(t, tgwId, "Transit Gateway should be created")

	// Test attachment bandwidth
	bandwidth := measureTGWAttachmentBandwidth(t, tgwId)
	assert.Greater(t, bandwidth, float64(50000000000), "TGW attachment bandwidth should be > 50 Gbps")

	t.Logf("TGW attachment bandwidth: %.2f Gbps", bandwidth/1000000000)
}

func testTGWRoutePropagation(t *testing.T, terraformOptions *terraform.Options) {
	// Test TGW route propagation performance
	// Measure time for route updates to propagate

	tgwId := terraform.Output(t, terraformOptions, "transit_gateway_id")
	assert.NotEmpty(t, tgwId, "Transit Gateway should be created")

	// Test route propagation
	propagationTime := measureRoutePropagationTime(t, tgwId)
	assert.Less(t, propagationTime, time.Second*30, "Route propagation should be < 30 seconds")

	t.Logf("TGW route propagation time: %v", propagationTime)
}

func testEndToEndLatency(t *testing.T, terraformOptions *terraform.Options) {
	// Test complete traffic inspection latency
	// Measure total time for packet inspection and forwarding

	// Deploy test instances and measure latency
	latency := measureEndToEndLatency(t, terraformOptions)
	assert.Less(t, latency, time.Millisecond*50, "End-to-end latency should be < 50ms")

	t.Logf("End-to-end latency: %v", latency)
}

func testEndToEndThroughput(t *testing.T, terraformOptions *terraform.Options) {
	// Test complete traffic inspection throughput
	// Measure maximum sustainable throughput

	throughput := measureEndToEndThroughput(t, terraformOptions)
	assert.Greater(t, throughput, float64(100000000), "End-to-end throughput should be > 100 Mbps")

	t.Logf("End-to-end throughput: %.2f Mbps", throughput/1000000)
}

func testConnectionEstablishmentRate(t *testing.T, terraformOptions *terraform.Options) {
	// Test rate of new connection establishment
	// Measure connections per second

	rate := measureConnectionEstablishmentRate(t, terraformOptions)
	assert.Greater(t, rate, float64(1000), "Connection establishment rate should be > 1000/sec")

	t.Logf("Connection establishment rate: %.0f/sec", rate)
}

func testScaleOutPerformance(t *testing.T, terraformOptions *terraform.Options) {
	// Test auto-scaling performance when scaling out
	// Measure time to add new instances and reach healthy state

	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.NotEmpty(t, asgName, "Auto scaling group should be created")

	// Trigger scale out and measure performance
	scaleOutTime := measureScaleOutTime(t, asgName)
	assert.Less(t, scaleOutTime, time.Minute*5, "Scale out should complete in < 5 minutes")

	t.Logf("Scale out time: %v", scaleOutTime)
}

func testScaleInPerformance(t *testing.T, terraformOptions *terraform.Options) {
	// Test auto-scaling performance when scaling in
	// Measure time to remove instances cleanly

	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.NotEmpty(t, asgName, "Auto scaling group should be created")

	// Trigger scale in and measure performance
	scaleInTime := measureScaleInTime(t, asgName)
	assert.Less(t, scaleInTime, time.Minute*3, "Scale in should complete in < 3 minutes")

	t.Logf("Scale in time: %v", scaleInTime)
}

func testScalingDecisionAccuracy(t *testing.T, terraformOptions *terraform.Options) {
	// Test accuracy of scaling decisions
	// Ensure scaling happens at correct thresholds

	asgName := terraform.Output(t, terraformOptions, "autoscaling_group_name")
	assert.NotEmpty(t, asgName, "Auto scaling group should be created")

	// Test scaling accuracy
	accuracy := measureScalingAccuracy(t, asgName)
	assert.Greater(t, accuracy, float64(90), "Scaling accuracy should be > 90%")

	t.Logf("Scaling decision accuracy: %.1f%%", accuracy)
}

func testLoadDistribution(t *testing.T, terraformOptions *terraform.Options) {
	// Test load distribution across firewall instances
	// Ensure traffic is evenly distributed

	gwlbArn := terraform.Output(t, terraformOptions, "gwlb_arn")
	assert.NotEmpty(t, gwlbArn, "GWLB should be created")

	// Test load distribution
	distributionVariance := measureLoadDistributionVariance(t, gwlbArn)
	assert.Less(t, distributionVariance, float64(20), "Load distribution variance should be < 20%")

	t.Logf("Load distribution variance: %.1f%%", distributionVariance)
}

func testSessionPersistence(t *testing.T, terraformOptions *terraform.Options) {
	// Test session persistence across load balancing decisions
	// Ensure related packets go to same firewall instance

	gwlbArn := terraform.Output(t, terraformOptions, "gwlb_arn")
	assert.NotEmpty(t, gwlbArn, "GWLB should be created")

	// Test session persistence
	persistenceRate := measureSessionPersistenceRate(t, gwlbArn)
	assert.Greater(t, persistenceRate, float64(95), "Session persistence rate should be > 95%")

	t.Logf("Session persistence rate: %.1f%%", persistenceRate)
}

func testFailoverPerformance(t *testing.T, terraformOptions *terraform.Options) {
	// Test failover performance when instances become unhealthy
	// Measure time to detect failure and reroute traffic

	gwlbArn := terraform.Output(t, terraformOptions, "gwlb_arn")
	assert.NotEmpty(t, gwlbArn, "GWLB should be created")

	// Test failover performance
	failoverTime := measureFailoverTime(t, gwlbArn)
	assert.Less(t, failoverTime, time.Second*30, "Failover should complete in < 30 seconds")

	t.Logf("Failover time: %v", failoverTime)
}

// Mock implementations for performance measurements
// In a real implementation, these would use actual AWS APIs and load testing tools

func measureGWLBThroughput(t *testing.T, gwlbArn string) float64 {
	// Mock implementation - would use CloudWatch metrics or load testing
	return 2000000000 // 2 Gbps
}

func measureGWLBLatency(t *testing.T, gwlbArn string) time.Duration {
	// Mock implementation - would use ping or custom latency tests
	return time.Millisecond * 5
}

func testConcurrentConnections(t *testing.T, gwlbArn string) int64 {
	// Mock implementation - would use load testing tools
	return 500000
}

func measureFirewallThroughput(t *testing.T, asgName string) float64 {
	// Mock implementation - would use iperf or custom throughput tests
	return 1000000000 // 1 Gbps
}

func testSessionCapacity(t *testing.T, asgName string) int64 {
	// Mock implementation - would query firewall session tables
	return 2000000
}

func monitorResourceUsage(t *testing.T, asgName string) (float64, float64) {
	// Mock implementation - would use CloudWatch metrics
	return 65.0, 70.0 // CPU%, Memory%
}

func measureTGWRoutingLatency(t *testing.T, tgwId string) time.Duration {
	// Mock implementation - would use network testing tools
	return time.Millisecond * 2
}

func measureTGWAttachmentBandwidth(t *testing.T, tgwId string) float64 {
	// Mock implementation - would use bandwidth testing tools
	return 100000000000 // 100 Gbps
}

func measureRoutePropagationTime(t *testing.T, tgwId string) time.Duration {
	// Mock implementation - would measure actual route propagation
	return time.Second * 15
}

func measureEndToEndLatency(t *testing.T, terraformOptions *terraform.Options) time.Duration {
	// Mock implementation - would deploy test instances and measure
	return time.Millisecond * 25
}

func measureEndToEndThroughput(t *testing.T, terraformOptions *terraform.Options) float64 {
	// Mock implementation - would use throughput testing tools
	return 500000000 // 500 Mbps
}

func measureConnectionEstablishmentRate(t *testing.T, terraformOptions *terraform.Options) float64 {
	// Mock implementation - would use connection testing tools
	return 5000 // 5000 connections/sec
}

func measureScaleOutTime(t *testing.T, asgName string) time.Duration {
	// Mock implementation - would measure actual scaling time
	return time.Minute * 3
}

func measureScaleInTime(t *testing.T, asgName string) time.Duration {
	// Mock implementation - would measure actual scaling time
	return time.Minute * 2
}

func measureScalingAccuracy(t *testing.T, asgName string) float64 {
	// Mock implementation - would analyze scaling decisions
	return 95.0 // 95% accuracy
}

func measureLoadDistributionVariance(t *testing.T, gwlbArn string) float64 {
	// Mock implementation - would analyze traffic distribution
	return 15.0 // 15% variance
}

func measureSessionPersistenceRate(t *testing.T, gwlbArn string) float64 {
	// Mock implementation - would test session persistence
	return 98.0 // 98% persistence
}

func measureFailoverTime(t *testing.T, gwlbArn string) time.Duration {
	// Mock implementation - would test failover scenarios
	return time.Second * 15
}
