package reporting

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
	"time"
)

// TestResult represents the result of a single test
type TestResult struct {
	TestName  string        `json:"test_name"`
	Package   string        `json:"package"`
	Status    string        `json:"status"` // "PASS", "FAIL", "SKIP"
	Duration  time.Duration `json:"duration"`
	Error     string        `json:"error,omitempty"`
	Output    string        `json:"output,omitempty"`
	Timestamp time.Time     `json:"timestamp"`
	Category  string        `json:"category"` // "unit", "integration", "performance", "security", etc.
}

// TestSuiteResult represents the results of a test suite execution
type TestSuiteResult struct {
	SuiteName    string        `json:"suite_name"`
	Environment  string        `json:"environment"`
	Region       string        `json:"region"`
	StartTime    time.Time     `json:"start_time"`
	EndTime      time.Time     `json:"end_time"`
	Duration     time.Duration `json:"duration"`
	TotalTests   int           `json:"total_tests"`
	PassedTests  int           `json:"passed_tests"`
	FailedTests  int           `json:"failed_tests"`
	SkippedTests int           `json:"skipped_tests"`
	Results      []TestResult  `json:"results"`
	Coverage     *CoverageInfo `json:"coverage,omitempty"`
	Performance  *PerfMetrics  `json:"performance,omitempty"`
}

// CoverageInfo represents code coverage information
type CoverageInfo struct {
	Percentage      float64            `json:"percentage"`
	Functions       int                `json:"functions"`
	Statements      int                `json:"statements"`
	FileCoverage    map[string]float64 `json:"file_coverage"`
	PackageCoverage map[string]float64 `json:"package_coverage"`
}

// PerfMetrics represents performance metrics
type PerfMetrics struct {
	AvgResponseTime time.Duration      `json:"avg_response_time"`
	MinResponseTime time.Duration      `json:"min_response_time"`
	MaxResponseTime time.Duration      `json:"max_response_time"`
	Throughput      float64            `json:"throughput"`
	ErrorRate       float64            `json:"error_rate"`
	ResourceUsage   map[string]float64 `json:"resource_usage"`
}

// TestAnalytics provides analytics and reporting for test results
type TestAnalytics struct {
	Results []TestSuiteResult `json:"results"`
}

// NewTestAnalytics creates a new test analytics instance
func NewTestAnalytics() *TestAnalytics {
	return &TestAnalytics{
		Results: make([]TestSuiteResult, 0),
	}
}

// AddResult adds a test suite result to the analytics
func (ta *TestAnalytics) AddResult(result TestSuiteResult) {
	ta.Results = append(ta.Results, result)
}

// GenerateReport generates a comprehensive test report
func (ta *TestAnalytics) GenerateReport(format string) (string, error) {
	switch format {
	case "json":
		return ta.generateJSONReport()
	case "html":
		return ta.generateHTMLReport()
	case "markdown":
		return ta.generateMarkdownReport()
	case "junit":
		return ta.generateJUnitReport()
	default:
		return "", fmt.Errorf("unsupported format: %s", format)
	}
}

// generateJSONReport generates a JSON report
func (ta *TestAnalytics) generateJSONReport() (string, error) {
	data, err := json.MarshalIndent(ta, "", "  ")
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// generateHTMLReport generates an HTML report
func (ta *TestAnalytics) generateHTMLReport() (string, error) {
	var html strings.Builder

	html.WriteString(`<!DOCTYPE html>
<html>
<head>
    <title>Test Analytics Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f0f0f0; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .test-result { margin: 10px 0; padding: 10px; border-left: 5px solid; }
        .pass { border-color: #28a745; background: #d4edda; }
        .fail { border-color: #dc3545; background: #f8d7da; }
        .skip { border-color: #ffc107; background: #fff3cd; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: white; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Test Analytics Report</h1>`)

	// Summary section
	html.WriteString("<div class='summary'>")
	html.WriteString("<h2>Summary</h2>")
	totalSuites := len(ta.Results)
	totalTests := 0
	totalPassed := 0
	totalFailed := 0
	totalSkipped := 0

	for _, suite := range ta.Results {
		totalTests += suite.TotalTests
		totalPassed += suite.PassedTests
		totalFailed += suite.FailedTests
		totalSkipped += suite.SkippedTests
	}

	passRate := float64(totalPassed) / float64(totalTests) * 100

	html.WriteString(fmt.Sprintf("<div class='metric'>Total Test Suites: %d</div>", totalSuites))
	html.WriteString(fmt.Sprintf("<div class='metric'>Total Tests: %d</div>", totalTests))
	html.WriteString(fmt.Sprintf("<div class='metric'>Passed: %d</div>", totalPassed))
	html.WriteString(fmt.Sprintf("<div class='metric'>Failed: %d</div>", totalFailed))
	html.WriteString(fmt.Sprintf("<div class='metric'>Skipped: %d</div>", totalSkipped))
	html.WriteString(fmt.Sprintf("<div class='metric'>Pass Rate: %.1f%%</div>", passRate))
	html.WriteString("</div>")

	// Detailed results
	html.WriteString("<h2>Detailed Results</h2>")
	for _, suite := range ta.Results {
		html.WriteString(fmt.Sprintf("<h3>%s (%s)</h3>", suite.SuiteName, suite.Environment))
		html.WriteString("<table>")
		html.WriteString("<tr><th>Test Name</th><th>Status</th><th>Duration</th><th>Category</th><th>Error</th></tr>")

		for _, result := range suite.Results {
			statusClass := strings.ToLower(result.Status)
			html.WriteString(fmt.Sprintf("<tr class='%s'>", statusClass))
			html.WriteString(fmt.Sprintf("<td>%s</td>", result.TestName))
			html.WriteString(fmt.Sprintf("<td>%s</td>", result.Status))
			html.WriteString(fmt.Sprintf("<td>%v</td>", result.Duration))
			html.WriteString(fmt.Sprintf("<td>%s</td>", result.Category))
			html.WriteString(fmt.Sprintf("<td>%s</td>", result.Error))
			html.WriteString("</tr>")
		}

		html.WriteString("</table>")
	}

	html.WriteString("</body></html>")
	return html.String(), nil
}

// generateMarkdownReport generates a Markdown report
func (ta *TestAnalytics) generateMarkdownReport() (string, error) {
	var md strings.Builder

	md.WriteString("# Test Analytics Report\n\n")

	// Summary
	md.WriteString("## Summary\n\n")
	totalSuites := len(ta.Results)
	totalTests := 0
	totalPassed := 0
	totalFailed := 0
	totalSkipped := 0

	for _, suite := range ta.Results {
		totalTests += suite.TotalTests
		totalPassed += suite.PassedTests
		totalFailed += suite.FailedTests
		totalSkipped += suite.SkippedTests
	}

	passRate := float64(totalPassed) / float64(totalTests) * 100

	md.WriteString(fmt.Sprintf("- **Total Test Suites**: %d\n", totalSuites))
	md.WriteString(fmt.Sprintf("- **Total Tests**: %d\n", totalTests))
	md.WriteString(fmt.Sprintf("- **Passed**: %d\n", totalPassed))
	md.WriteString(fmt.Sprintf("- **Failed**: %d\n", totalFailed))
	md.WriteString(fmt.Sprintf("- **Skipped**: %d\n", totalSkipped))
	md.WriteString(fmt.Sprintf("- **Pass Rate**: %.1f%%\n\n", passRate))

	// Detailed results
	md.WriteString("## Detailed Results\n\n")
	for _, suite := range ta.Results {
		md.WriteString(fmt.Sprintf("### %s (%s)\n\n", suite.SuiteName, suite.Environment))
		md.WriteString("| Test Name | Status | Duration | Category | Error |\n")
		md.WriteString("|-----------|--------|----------|----------|-------|\n")

		for _, result := range suite.Results {
			errorMsg := result.Error
			if len(errorMsg) > 50 {
				errorMsg = errorMsg[:47] + "..."
			}
			md.WriteString(fmt.Sprintf("| %s | %s | %v | %s | %s |\n",
				result.TestName, result.Status, result.Duration, result.Category, errorMsg))
		}
		md.WriteString("\n")
	}

	return md.String(), nil
}

// generateJUnitReport generates a JUnit XML report
func (ta *TestAnalytics) generateJUnitReport() (string, error) {
	var xml strings.Builder

	xml.WriteString(`<?xml version="1.0" encoding="UTF-8"?>
<testsuites>`)

	for _, suite := range ta.Results {
		xml.WriteString(fmt.Sprintf(`
  <testsuite name="%s" tests="%d" failures="%d" skipped="%d" time="%.3f">`,
			suite.SuiteName, suite.TotalTests, suite.FailedTests, suite.SkippedTests, suite.Duration.Seconds()))

		for _, result := range suite.Results {
			xml.WriteString(fmt.Sprintf(`
    <testcase name="%s" classname="%s" time="%.3f">`,
				result.TestName, result.Package, result.Duration.Seconds()))

			if result.Status == "FAIL" && result.Error != "" {
				xml.WriteString(fmt.Sprintf(`
      <failure message="%s">%s</failure>`, result.Error, result.Output))
			} else if result.Status == "SKIP" {
				xml.WriteString(`
      <skipped/>`)
			}

			xml.WriteString(`
    </testcase>`)
		}

		xml.WriteString(`
  </testsuite>`)
	}

	xml.WriteString(`
</testsuites>`)

	return xml.String(), nil
}

// GetMetrics returns aggregated metrics across all test suites
func (ta *TestAnalytics) GetMetrics() map[string]interface{} {
	totalSuites := len(ta.Results)
	totalTests := 0
	totalPassed := 0
	totalFailed := 0
	totalSkipped := 0
	totalDuration := time.Duration(0)

	categoryStats := make(map[string]map[string]int)
	packageStats := make(map[string]map[string]int)

	for _, suite := range ta.Results {
		totalTests += suite.TotalTests
		totalPassed += suite.PassedTests
		totalFailed += suite.FailedTests
		totalSkipped += suite.SkippedTests
		totalDuration += suite.Duration

		for _, result := range suite.Results {
			// Category statistics
			if categoryStats[result.Category] == nil {
				categoryStats[result.Category] = map[string]int{
					"total": 0, "passed": 0, "failed": 0, "skipped": 0,
				}
			}
			categoryStats[result.Category]["total"]++
			categoryStats[result.Category][strings.ToLower(result.Status)]++

			// Package statistics
			if packageStats[result.Package] == nil {
				packageStats[result.Package] = map[string]int{
					"total": 0, "passed": 0, "failed": 0, "skipped": 0,
				}
			}
			packageStats[result.Package]["total"]++
			packageStats[result.Package][strings.ToLower(result.Status)]++
		}
	}

	passRate := float64(totalPassed) / float64(totalTests) * 100
	avgDuration := totalDuration / time.Duration(totalSuites)

	return map[string]interface{}{
		"total_suites":   totalSuites,
		"total_tests":    totalTests,
		"passed_tests":   totalPassed,
		"failed_tests":   totalFailed,
		"skipped_tests":  totalSkipped,
		"pass_rate":      passRate,
		"total_duration": totalDuration,
		"avg_duration":   avgDuration,
		"category_stats": categoryStats,
		"package_stats":  packageStats,
	}
}

// GetTrendAnalysis performs trend analysis on test results
func (ta *TestAnalytics) GetTrendAnalysis() map[string]interface{} {
	if len(ta.Results) < 2 {
		return map[string]interface{}{
			"error": "Need at least 2 test suite results for trend analysis",
		}
	}

	// Sort results by start time
	sortedResults := make([]TestSuiteResult, len(ta.Results))
	copy(sortedResults, ta.Results)
	sort.Slice(sortedResults, func(i, j int) bool {
		return sortedResults[i].StartTime.Before(sortedResults[j].StartTime)
	})

	// Calculate trends
	passRateTrend := make([]float64, len(sortedResults))
	durationTrend := make([]time.Duration, len(sortedResults))

	for i, result := range sortedResults {
		if result.TotalTests > 0 {
			passRateTrend[i] = float64(result.PassedTests) / float64(result.TotalTests) * 100
		}
		durationTrend[i] = result.Duration
	}

	// Calculate improvement/regression
	firstPassRate := passRateTrend[0]
	lastPassRate := passRateTrend[len(passRateTrend)-1]
	passRateChange := lastPassRate - firstPassRate

	firstDuration := durationTrend[0]
	lastDuration := durationTrend[len(durationTrend)-1]
	durationChange := lastDuration - firstDuration

	return map[string]interface{}{
		"pass_rate_trend":  passRateTrend,
		"duration_trend":   durationTrend,
		"pass_rate_change": passRateChange,
		"duration_change":  durationChange,
		"improving":        passRateChange > 0 && durationChange < 0,
		"regressing":       passRateChange < 0 || durationChange > 0,
	}
}

// ExportResults exports test results to a file
func (ta *TestAnalytics) ExportResults(filename, format string) error {
	report, err := ta.GenerateReport(format)
	if err != nil {
		return err
	}

	// Create directory if it doesn't exist
	dir := "test-reports"
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	// Add timestamp to filename
	timestamp := time.Now().Format("2006-01-02_15-04-05")
	fullFilename := fmt.Sprintf("%s/%s_%s.%s", dir, strings.TrimSuffix(filename, "."+format), timestamp, format)

	return os.WriteFile(fullFilename, []byte(report), 0644)
}

// GetFailedTests returns all failed tests across all suites
func (ta *TestAnalytics) GetFailedTests() []TestResult {
	var failedTests []TestResult

	for _, suite := range ta.Results {
		for _, result := range suite.Results {
			if result.Status == "FAIL" {
				failedTests = append(failedTests, result)
			}
		}
	}

	return failedTests
}

// GetSlowTests returns tests that took longer than the specified duration
func (ta *TestAnalytics) GetSlowTests(threshold time.Duration) []TestResult {
	var slowTests []TestResult

	for _, suite := range ta.Results {
		for _, result := range suite.Results {
			if result.Duration > threshold {
				slowTests = append(slowTests, result)
			}
		}
	}

	return slowTests
}

// GetTestCategories returns all unique test categories
func (ta *TestAnalytics) GetTestCategories() []string {
	categorySet := make(map[string]bool)

	for _, suite := range ta.Results {
		for _, result := range suite.Results {
			categorySet[result.Category] = true
		}
	}

	var categories []string
	for category := range categorySet {
		categories = append(categories, category)
	}

	sort.Strings(categories)
	return categories
}

// GetTestPackages returns all unique test packages
func (ta *TestAnalytics) GetTestPackages() []string {
	packageSet := make(map[string]bool)

	for _, suite := range ta.Results {
		for _, result := range suite.Results {
			packageSet[result.Package] = true
		}
	}

	var packages []string
	for pkg := range packageSet {
		packages = append(packages, pkg)
	}

	sort.Strings(packages)
	return packages
}
