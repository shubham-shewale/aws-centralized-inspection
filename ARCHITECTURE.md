# AWS Centralized Traffic Inspection Architecture

## Overview

This document provides detailed architectural diagrams and explanations for the AWS centralized traffic inspection solution using Palo Alto firewalls with Gateway Load Balancer (GWLB) and Transit Gateway (TGW).

## High-Level Architecture

```mermaid
graph TB
    subgraph "AWS Cloud"
        subgraph "Security/Network Account"
            subgraph "Inspection VPC"
                GWLB[Gateway Load Balancer]
                FW1[Firewall Instance 1]
                FW2[Firewall Instance 2]
                IGW[Internet Gateway]
                RT1[Route Tables]
            end

            TGW[Transit Gateway]
        end

        subgraph "Application Account 1"
            subgraph "Spoke VPC 1"
                APP1[Application Servers]
                GWLBE1[GWLB Endpoint]
                RT2[Route Tables]
            end
        end

        subgraph "Application Account 2"
            subgraph "Spoke VPC 2"
                APP2[Application Servers]
                GWLBE2[GWLB Endpoint]
                RT3[Route Tables]
            end
        end
    end

    APP1 --> RT2
    RT2 --> GWLBE1
    GWLBE1 --> GWLB
    GWLB --> FW1
    GWLB --> FW2
    FW1 --> RT1
    FW2 --> RT1
    RT1 --> IGW

    APP2 --> RT3
    RT3 --> GWLBE2
    GWLBE2 --> GWLB

    GWLBE1 -.-> TGW
    GWLBE2 -.-> TGW
    TGW -.-> RT1

    style GWLB fill:#e1f5fe
    style TGW fill:#f3e5f5
    style FW1 fill:#e8f5e8
    style FW2 fill:#e8f5e8
```

## Detailed Component Architecture

### 1. Inspection VPC Architecture

```mermaid
graph TD
    subgraph "Inspection VPC (10.0.0.0/16)"
        subgraph "Public Subnets (AZ-1)"
            GWLB_PUB[GWLB Subnet<br/>10.0.10.0/24]
        end

        subgraph "Private Subnets (AZ-1)"
            FW_PRIV[Firewall Subnet<br/>10.0.20.0/24]
        end

        subgraph "Public Subnets (AZ-2)"
            GWLB_PUB2[GWLB Subnet<br/>10.0.11.0/24]
        end

        subgraph "Private Subnets (AZ-2)"
            FW_PRIV2[Firewall Subnet<br/>10.0.21.0/24]
        end

        IGW[Internet Gateway]
        NAT[NAT Gateway]
        RT_PUB[Public Route Table]
        RT_PRIV[Private Route Table]
    end

    GWLB_PUB --> RT_PUB
    RT_PUB --> IGW
    FW_PRIV --> RT_PRIV
    RT_PRIV --> NAT
    NAT --> IGW

    GWLB_PUB2 --> RT_PUB
    FW_PRIV2 --> RT_PRIV
```

### 2. Gateway Load Balancer Architecture

```mermaid
graph TD
    subgraph "Gateway Load Balancer"
        LISTENER[Listener<br/>Port: 6081<br/>Protocol: GENEVE]

        TG[target-group<br/>Protocol: GENEVE<br/>Port: 6081]

        HC[Health Check<br/>TCP: 22<br/>Interval: 30s<br/>Timeout: 5s]
    end

    subgraph "Firewall Instances"
        FW1[VM-Series 1<br/>ENI: eth0<br/>IP: 10.0.20.10]
        FW2[VM-Series 2<br/>ENI: eth0<br/>IP: 10.0.20.11]
        FW3[VM-Series 3<br/>ENI: eth0<br/>IP: 10.0.21.10]
        FW4[VM-Series 4<br/>ENI: eth0<br/>IP: 10.0.21.11]
    end

    LISTENER --> TG
    TG --> FW1
    TG --> FW2
    TG --> FW3
    TG --> FW4

    HC -.-> FW1
    HC -.-> FW2
    HC -.-> FW3
    HC -.-> FW4
```

### 3. Transit Gateway Architecture

```mermaid
graph TD
    subgraph "Transit Gateway"
        TGW_CORE[TGW Core<br/>ASN: 64512]

        subgraph "Route Tables"
            RT_INSPECTION[Inspection RT<br/>Routes to Spoke VPCs]
            RT_SPOKE[Spoke RT<br/>Routes to Inspection VPC]
        end

        subgraph "VPC Attachments"
            ATTACH_INSPECTION[Inspection VPC<br/>Attachment]
            ATTACH_SPOKE1[Spoke VPC 1<br/>Attachment]
            ATTACH_SPOKE2[Spoke VPC 2<br/>Attachment]
        end
    end

    TGW_CORE --> RT_INSPECTION
    TGW_CORE --> RT_SPOKE

    RT_INSPECTION --> ATTACH_SPOKE1
    RT_INSPECTION --> ATTACH_SPOKE2
    RT_SPOKE --> ATTACH_INSPECTION

    ATTACH_INSPECTION -.-> RT_INSPECTION
    ATTACH_SPOKE1 -.-> RT_SPOKE
    ATTACH_SPOKE2 -.-> RT_SPOKE
```

## Traffic Flow Diagrams

### North-South Traffic Flow (Internet-bound)

```mermaid
sequenceDiagram
    participant App as Application Server
    participant RT as Route Table
    participant GWLBE as GWLB Endpoint
    participant GWLB as Gateway Load Balancer
    participant FW as Firewall Instance
    participant IGW as Internet Gateway
    participant Internet as Internet

    App->>RT: Packet to 8.8.8.8
    RT->>GWLBE: Route via GWLB Endpoint
    GWLBE->>GWLB: GENEVE encapsulated packet
    GWLB->>FW: Load balanced to firewall
    FW->>FW: Inspect packet (URL filtering, threat prevention)
    FW->>GWLB: Allow/deny decision
    GWLB->>GWLBE: Return traffic
    GWLBE->>RT: Decapsulated packet
    RT->>IGW: Route to internet
    IGW->>Internet: Forward to destination

    Note over FW: Stateful inspection maintains<br/>session context for return traffic
```

### East-West Traffic Flow (Inter-VPC)

```mermaid
sequenceDiagram
    participant App1 as App Server (VPC 1)
    participant RT1 as Route Table (VPC 1)
    participant GWLBE1 as GWLB Endpoint (VPC 1)
    participant GWLB as Gateway Load Balancer
    participant FW as Firewall Instance
    participant TGW as Transit Gateway
    participant RT2 as Route Table (VPC 2)
    participant App2 as App Server (VPC 2)

    App1->>RT1: Packet to 10.2.1.10
    RT1->>GWLBE1: Route via GWLB Endpoint
    GWLBE1->>GWLB: GENEVE encapsulated packet
    GWLB->>FW: Load balanced to firewall
    FW->>FW: Inspect packet (east-west rules)
    FW->>GWLB: Allow decision
    GWLB->>GWLBE1: Return traffic
    GWLBE1->>TGW: Route to destination VPC
    TGW->>RT2: Forward to spoke VPC
    RT2->>App2: Deliver to application

    Note over TGW: Symmetric routing ensures<br/>return traffic follows same path
```

## Network Segmentation Details

### Subnet Design

```
Inspection VPC (10.0.0.0/16)
├── Public Subnets (GWLB)
│   ├── 10.0.10.0/24 (AZ-1)
│   ├── 10.0.11.0/24 (AZ-2)
│   └── 10.0.12.0/24 (AZ-3)
├── Private Subnets (Firewalls)
│   ├── 10.0.20.0/24 (AZ-1)
│   ├── 10.0.21.0/24 (AZ-2)
│   └── 10.0.22.0/24 (AZ-3)
└── Management Subnets (Optional)
    ├── 10.0.30.0/24 (AZ-1)
    ├── 10.0.31.0/24 (AZ-2)
    └── 10.0.32.0/24 (AZ-3)

Spoke VPC 1 (10.1.0.0/16)
├── Public Subnets
│   ├── 10.1.10.0/24 (AZ-1)
│   ├── 10.1.11.0/24 (AZ-2)
│   └── 10.1.12.0/24 (AZ-3)
├── Private Subnets
│   ├── 10.1.20.0/24 (AZ-1)
│   ├── 10.1.21.0/24 (AZ-2)
│   └── 10.1.22.0/24 (AZ-3)
└── Database Subnets
    ├── 10.1.30.0/24 (AZ-1)
    ├── 10.1.31.0/24 (AZ-2)
    └── 10.1.32.0/24 (AZ-3)
```

## Security Architecture

### Defense in Depth Layers

```mermaid
graph TD
    subgraph "Layer 7 - Application"
        WAF[Web Application Firewall]
        API[API Gateway Security]
    end

    subgraph "Layer 4 - Transport"
        GWLB[Gateway Load Balancer]
        FW[Next-Gen Firewall]
    end

    subgraph "Layer 3 - Network"
        NACL[Network ACLs]
        SG[Security Groups]
        TGW[Transit Gateway]
    end

    subgraph "Layer 2 - Data Link"
        VPC[VPC Flow Logs]
        ENI[ENI Security]
    end

    WAF --> GWLB
    API --> GWLB
    GWLB --> FW
    FW --> NACL
    NACL --> SG
    SG --> TGW
    TGW --> VPC
    VPC --> ENI

    style FW fill:#e8f5e8
    style GWLB fill:#e1f5fe
    style TGW fill:#f3e5f5
```

### Firewall Rule Architecture

```mermaid
graph TD
    subgraph "Security Policy Structure"
        PRE[Pre-Rules<br/>Intrazone: Allow]
        INTRA[Intrazone Rules<br/>East-West Traffic]
        INTER[Interzone Rules<br/>North-South Traffic]
        POST[Post-Rules<br/>Default: Deny]
    end

    subgraph "Rule Evaluation Order"
        STEP1[Step 1: Pre-Rules]
        STEP2[Step 2: Intrazone]
        STEP3[Step 3: Interzone]
        STEP4[Step 4: Post-Rules]
    end

    PRE --> STEP1
    INTRA --> STEP2
    INTER --> STEP3
    POST --> STEP4

    STEP1 --> STEP2
    STEP2 --> STEP3
    STEP3 --> STEP4
```

## High Availability Architecture

### Multi-AZ Deployment

```mermaid
graph TD
    subgraph "Availability Zone 1"
        GWLB1[GWLB Node 1]
        FW1_1[Firewall 1-1]
        FW1_2[Firewall 1-2]
    end

    subgraph "Availability Zone 2"
        GWLB2[GWLB Node 2]
        FW2_1[Firewall 2-1]
        FW2_2[Firewall 2-2]
    end

    subgraph "Availability Zone 3"
        GWLB3[GWLB Node 3]
        FW3_1[Firewall 3-1]
        FW3_2[Firewall 3-2]
    end

    GWLB1 --- GWLB2
    GWLB2 --- GWLB3
    GWLB1 --- GWLB3

    FW1_1 -.-> GWLB1
    FW1_2 -.-> GWLB1
    FW2_1 -.-> GWLB2
    FW2_2 -.-> GWLB2
    FW3_1 -.-> GWLB3
    FW3_2 -.-> GWLB3
```

### Auto-scaling Architecture

```mermaid
graph TD
    subgraph "Auto Scaling Group"
        ASG[Auto Scaling Group<br/>Min: 2, Max: 6]

        subgraph "Scaling Policies"
            CPU_HIGH[CPU > 70%<br/>Scale Out]
            CPU_LOW[CPU < 30%<br/>Scale In]
            MEM_HIGH[Memory > 80%<br/>Scale Out]
            MEM_LOW[Memory < 40%<br/>Scale In]
        end
    end

    subgraph "CloudWatch Alarms"
        ALARM1[CPU High Alarm]
        ALARM2[CPU Low Alarm]
        ALARM3[Memory High Alarm]
        ALARM4[Memory Low Alarm]
    end

    subgraph "Load Balancer"
        TG[Target Group]
        HC[Health Checks]
    end

    ASG --> CPU_HIGH
    ASG --> CPU_LOW
    ASG --> MEM_HIGH
    ASG --> MEM_LOW

    CPU_HIGH --> ALARM1
    CPU_LOW --> ALARM2
    MEM_HIGH --> ALARM3
    MEM_LOW --> ALARM4

    ASG -.-> TG
    HC -.-> ASG
```

## Monitoring and Observability

### Metrics Architecture

```mermaid
graph TD
    subgraph "AWS Services"
        GWLB[GWLB Metrics]
        EC2[EC2 Metrics]
        TGW[TGW Metrics]
        VPC[VPC Metrics]
    end

    subgraph "Custom Metrics"
        LATENCY[Traffic Latency]
        THROUGHPUT[Throughput]
        DROP_RATE[Drop Rate]
        SESSION_COUNT[Active Sessions]
    end

    subgraph "Monitoring Tools"
        CW[CloudWatch]
        XRAY[X-Ray]
        CUSTOM[Custom Dashboards]
    end

    subgraph "Alerting"
        SNS[SNS Topics]
        LAMBDA[Lambda Functions]
        EMAIL[Email Notifications]
    end

    GWLB --> CW
    EC2 --> CW
    TGW --> CW
    VPC --> CW

    LATENCY --> CW
    THROUGHPUT --> CW
    DROP_RATE --> CW
    SESSION_COUNT --> CW

    CW --> CUSTOM
    CW --> XRAY

    CW --> SNS
    SNS --> LAMBDA
    LAMBDA --> EMAIL
```

## Deployment Architecture

### Terraform Module Structure

```mermaid
graph TD
    subgraph "Root Module"
        MAIN[main.tf<br/>Orchestrates all modules]
        VARS[variables.tf<br/>Global variables]
        OUTPUTS[outputs.tf<br/>Resource outputs]
    end

    subgraph "Core Modules"
        NETWORK[network module<br/>VPCs, TGW, routes]
        INSPECTION[inspection module<br/>GWLB, endpoints]
        OBSERVABILITY[observability module<br/>Flow logs, monitoring]
    end

    subgraph "Firewall Modules"
        VMSERIES[vmseries module<br/>VM-Series deployment]
        CLOUDNGFW[cloudngfw module<br/>Cloud NGFW setup]
        PANOS[panos module<br/>Policy management]
    end

    MAIN --> NETWORK
    MAIN --> INSPECTION
    MAIN --> OBSERVABILITY
    MAIN --> VMSERIES
    MAIN --> CLOUDNGFW
    MAIN --> PANOS

    NETWORK -.-> INSPECTION
    NETWORK -.-> VMSERIES
    INSPECTION -.-> VMSERIES
    OBSERVABILITY -.-> NETWORK
    OBSERVABILITY -.-> INSPECTION
    PANOS -.-> VMSERIES
```

## Performance Considerations

### Throughput Optimization

```mermaid
graph TD
    subgraph "Traffic Distribution"
        INGRESS[Ingress Traffic]
        EGRESS[Egress Traffic]
        EASTWEST[East-West Traffic]
    end

    subgraph "Load Balancing"
        GWLB_DIST[GWLB Distribution]
        AZ_DIST[AZ Distribution]
        FW_DIST[Firewall Distribution]
    end

    subgraph "Optimization Techniques"
        SESSION_AFF[Session Affinity]
        CONNECTION_POOL[Connection Pooling]
        CACHE[Rule Caching]
        FASTPATH[Fast Path]
    end

    INGRESS --> GWLB_DIST
    EGRESS --> GWLB_DIST
    EASTWEST --> GWLB_DIST

    GWLB_DIST --> AZ_DIST
    AZ_DIST --> FW_DIST

    FW_DIST --> SESSION_AFF
    FW_DIST --> CONNECTION_POOL
    FW_DIST --> CACHE
    FW_DIST --> FASTPATH
```

## Compliance Architecture

### Security Standards Mapping

```mermaid
graph TD
    subgraph "Compliance Frameworks"
        PCI[PCI DSS]
        HIPAA[HIPAA]
        SOC2[SOC 2]
        GDPR[GDPR]
    end

    subgraph "Security Controls"
        ENCRYPTION[Data Encryption]
        AUDIT[Audit Logging]
        ACCESS[Access Control]
        MONITORING[Continuous Monitoring]
    end

    subgraph "Implementation"
        KMS[KMS Encryption]
        FLOWLOGS[VPC Flow Logs]
        IAM[IAM Policies]
        CLOUDWATCH[CloudWatch Monitoring]
    end

    PCI --> ENCRYPTION
    HIPAA --> AUDIT
    SOC2 --> ACCESS
    GDPR --> MONITORING

    ENCRYPTION --> KMS
    AUDIT --> FLOWLOGS
    ACCESS --> IAM
    MONITORING --> CLOUDWATCH
```

## Disaster Recovery Architecture

### Multi-Region Deployment

```mermaid
graph TD
    subgraph "Primary Region"
        VPC1[Inspection VPC]
        TGW1[Transit Gateway]
        FW1[Firewall Instances]
    end

    subgraph "DR Region"
        VPC2[Inspection VPC]
        TGW2[Transit Gateway]
        FW2[Firewall Instances]
    end

    subgraph "Global Resources"
        ROUTE53[Route 53<br/>DNS Failover]
        CF[CloudFront<br/>Global Distribution]
        IAM[IAM Roles<br/>Cross-Region]
    end

    VPC1 -.-> ROUTE53
    VPC2 -.-> ROUTE53
    FW1 -.-> CF
    FW2 -.-> CF
    IAM -.-> VPC1
    IAM -.-> VPC2

    TGW1 -.-> TGW2
```

## Automated Remediation Architecture

### Security Event Processing Flow

```mermaid
graph TD
    subgraph "Security Events"
        EC2_EVENTS[EC2 API Calls<br/>Security Group Changes]
        ELB_EVENTS[ELB Events<br/>Traffic Anomalies]
        IAM_EVENTS[IAM Events<br/>Policy Changes]
    end

    subgraph "Event Processing"
        CW_EVENTS[CloudWatch Events]
        LAMBDA[Lambda Function<br/>Security Automation]
        SNS[Security Alerts<br/>SNS Topic]
    end

    subgraph "Automated Responses"
        SG_FIX[Security Group<br/>Auto-Remediation]
        INSTANCE_QUARANTINE[Instance Quarantine]
        ALERT_GENERATION[Alert Generation]
    end

    subgraph "Monitoring & Logging"
        CW_LOGS[CloudWatch Logs]
        METRICS[Security Metrics]
        DASHBOARDS[Security Dashboards]
    end

    EC2_EVENTS --> CW_EVENTS
    ELB_EVENTS --> CW_EVENTS
    IAM_EVENTS --> CW_EVENTS

    CW_EVENTS --> LAMBDA
    LAMBDA --> SNS
    LAMBDA --> SG_FIX
    LAMBDA --> INSTANCE_QUARANTINE
    LAMBDA --> ALERT_GENERATION

    SG_FIX --> CW_LOGS
    INSTANCE_QUARANTINE --> CW_LOGS
    ALERT_GENERATION --> CW_LOGS

    CW_LOGS --> METRICS
    METRICS --> DASHBOARDS

    style LAMBDA fill:#e8f5e8
    style SNS fill:#fff3e0
    style CW_EVENTS fill:#e1f5fe
```

### Remediation Workflow

1. **Event Detection**: CloudWatch Events capture security-related API calls and system events
2. **Event Processing**: Lambda function analyzes events for security violations
3. **Automated Response**: Immediate remediation actions for detected issues
4. **Alert Generation**: Security team notifications via SNS
5. **Audit Logging**: All actions logged for compliance and forensic analysis

### Supported Remediation Actions

- **Security Group Hardening**: Automatic restriction of overly permissive rules
- **Instance Isolation**: Quarantine compromised or misconfigured instances
- **Access Revocation**: Removal of unauthorized access permissions
- **Configuration Correction**: Automatic fixing of security misconfigurations
- **Alert Escalation**: Priority-based security incident notifications

## Security Enhancements (Latest Updates)

### Recent Security Improvements

#### 🔒 Mandatory Encryption
- **EBS Encryption**: All VM-Series instances now use customer-managed KMS keys
- **S3 Encryption**: Flow logs and configuration data encrypted with KMS
- **State Encryption**: Terraform state files encrypted with dedicated KMS keys
- **TLS 1.2+**: Enhanced SSL/TLS configurations for secure communications

#### 🛡️ Enhanced Access Controls
- **Least Privilege IAM**: Strengthened policies with explicit deny statements
- **Cross-Account Access**: Secure cross-account IAM roles with MFA requirements
- **Security Group Hardening**: Restrictive ingress rules with specific port/protocol access
- **Network ACLs**: Comprehensive network segmentation with proper ingress/egress rules

#### 🤖 Automated Remediation
- **Lambda Security Automation**: Event-driven response to security events
- **Security Group Monitoring**: Automatic restriction of overly permissive rules
- **CloudWatch Integration**: Real-time security event processing and alerting
- **SNS Notifications**: Automated security incident notifications

#### 📊 Advanced Monitoring
- **VPC Flow Logs**: Enabled for all VPCs with CloudWatch integration
- **TGW Flow Logs**: Transit Gateway traffic monitoring and analysis
- **Security Alarms**: CloudWatch alarms for security events and threats
- **Custom Dashboards**: Security-specific monitoring dashboards

#### ✅ Compliance Framework Support
- **PCI DSS**: Payment card data protection controls
- **HIPAA**: Healthcare data compliance with audit logging
- **SOC 2**: Security, availability, and confidentiality
- **GDPR**: Data protection and privacy requirements
- **NIST 800-53**: Federal information security controls

### Architecture Validation

#### Security Validation Checklist
- [x] EBS encryption enabled with KMS
- [x] Security groups restrict unnecessary access
- [x] Network ACLs provide proper segmentation
- [x] VPC Flow Logs configured and active
- [x] CloudWatch alarms for security monitoring
- [x] Data classification tags applied
- [x] Compliance frameworks documented

This architecture document provides the foundation for understanding the AWS centralized traffic inspection solution with enhanced security features. For implementation details, refer to the deployment guide and troubleshooting documentation.