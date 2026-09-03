#!/usr/bin/env python3
"""English O&M Hotline Training deck for Huawei Cloud (HCS 8.6.1).

Covers: architecture, services, SR/ticket process, ITR flow, TAC email,
mailbox handling, common operations, best practices. ~1 hour training.
"""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 '..', '..', '..', 'templates', 'ppt'))
from huawei_ppt import *

OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def main():
    prs, layouts = new_deck()

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 1 — Title
    # ═══════════════════════════════════════════════════════════════
    title_slide(prs, layouts,
                "Huawei Cloud O&M Hotline Training",
                "HCS 8.6.1 | Operations & Maintenance",
                "Module 1 | English")

    # ═══════════════════════════════════════════════════════════════
    # SLIDE 2 — Agenda
    # ═══════════════════════════════════════════════════════════════
    s = content_slide(prs, layouts, "Training Agenda")
    text_box(s, "1. HCS 8.6.1 Architecture\n"
                "2. Service Families and Acronyms\n"
                "3. SR Opening Process\n"
                "4. TAC Notification and SR Template\n"
                "5. ITR (Issue To Resolve) Process\n"
                "6. Escalation Matrix\n"
                "7. Common O&M Operations\n"
                "8. Best Practices and Checklist",
             Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
             Inches(CONTENT_WIDTH), Inches(4.5), 16, DARK)

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 1 — Architecture
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "HCS 8.6.1 Architecture",
                  "Management Plane and Data Plane")

    # SLIDE — Architecture Overview
    s = content_slide(prs, layouts, "Architecture Overview")
    text_box(s,
        "HCS (Huawei Cloud Stack) is an on-premise private cloud solution.\n\n"
        "Main components:\n"
        "  • ManageOne — unified operations platform (O&M)\n"
        "  • ServiceCenter — self-service portal and service catalog\n"
        "  • FusionSphere — virtualization (compute, storage, network)\n"
        "  • OMBase — operations database\n\n"
        "Target version: HCS 8.6.1\n"
        "Goal: team authoring content starting 09/01",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)

    # SLIDE — Management vs Data Plane
    s = content_slide(prs, layouts, "Management Plane vs Data Plane")
    add_table(s,
        ["Layer", "Components", "Function"],
        [
            ["Management", "ManageOne, OMBase", "O&M, monitoring, billing"],
            ["Management", "ServiceCenter, Catalog", "Self-service, provisioning"],
            ["Data — Compute", "FusionCompute, ECS", "VMs, containers, auto scaling"],
            ["Data — Storage", "FusionStorage, EVS, OBS", "Block, object, file storage"],
            ["Data — Network", "VPC, EIP, ELB", "Virtual network, IP, load balancing"],
        ])
    callout(s, 'infobox',
            "ManageOne is the operations platform — not a cloud service. "
            "ServiceCenter is the self-service portal.",
            top=5.2)

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 2 — Services (expanded — the most important section)
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "Cloud Services",
                  "Families, details, and what the hotline needs to know")

    # SLIDE — Service Families (overview)
    s = content_slide(prs, layouts, "Cloud Service Families")
    add_table(s,
        ["Family", "Key Services", "Count"],
        [
            ["Compute", "ECS, IMS, AS, CCE", "4"],
            ["Storage", "EVS, OBS, SFS, HBR", "4"],
            ["Network", "VPC, EIP, ELB, NAT, VPN, DNS", "6"],
            ["Database", "RDS, GaussDB, DRS, DDS", "4"],
            ["Security", "Anti-DDoS, WAF, IAM, KMS", "4"],
        ])
    callout(s, 'tip',
            "The hotline must know the official service name for SR routing. "
            "Each family has its own characteristics and common issues — covered next.",
            top=5.2)

    # SLIDE — Compute in detail
    s = content_slide(prs, layouts, "Compute — Services in Detail")
    add_table(s,
        ["Svc", "What It Is", "When to Use", "Check First"],
        [
            ["ECS", "Virtual server you rent in the cloud",
             "Web apps, APIs, data processing",
             "VM status, quotas, system events"],
            ["IMS", "Image/template to create VMs fast",
             "Repeatable, standardized deployments",
             "Image exists? Correct version?"],
            ["AS", "Adds/removes VMs automatically by demand",
             "Traffic spikes, variable workloads",
             "Scaling policies, min/max instances"],
            ["CCE", "Managed Kubernetes (containers)",
             "Microservices, modern applications",
             "Pod status, ready nodes, quotas"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'infobox',
            "ECS is the most common service — most compute SRs start here. "
            "Always confirm: VM name, flavor (CPU/RAM), and current status.",
            top=5.2)

    # SLIDE — Storage in detail
    s = content_slide(prs, layouts, "Storage — Services in Detail")
    add_table(s,
        ["Svc", "What It Is", "When to Use", "Check First"],
        [
            ["EVS", "Virtual disk attached to a VM",
             "System and data disks",
             "Capacity, IOPS, attached?"],
            ["OBS", "Object storage (S3-like)",
             "Backups, media, static files",
             "AK/SK valid? Bucket exists?"],
            ["SFS", "Shared file system",
             "Files shared across VMs",
             "Mount point, quota, performance"],
            ["HBR", "Hybrid backup and recovery",
             "DR, VM and data backups",
             "Backup ran? Restore tested?"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'warning',
            "Disk full (>90%) is the most common storage issue. "
            "Always check capacity and IOPS before escalating.",
            top=5.2)

    # SLIDE — Network in detail
    s = content_slide(prs, layouts, "Network — Services in Detail")
    add_table(s,
        ["Svc", "What It Is", "When to Use", "Check First"],
        [
            ["VPC", "Isolated private network in the cloud",
             "All cloud resources",
             "Subnets, route tables, SG"],
            ["EIP", "Public IP for external access",
             "Internet-facing services",
             "EIP associated? Reachability"],
            ["ELB", "Distributes traffic across servers",
             "High availability, scaling",
             "Health checks, backends healthy?"],
            ["NAT", "Private VMs reach the internet",
             "VMs without EIP needing internet",
             "NAT rules, gateway active?"],
            ["VPN", "Secure tunnel on-prem to cloud",
             "Hybrid connection, remote access",
             "Tunnel up? Routes correct?"],
            ["DNS", "Name resolution to IPs",
             "All services with names",
             "Zone exists? Records correct?"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'infobox',
            "Network issues almost always involve Security Groups or VPC. "
            "Confirm SG (open ports) and route table before escalating.",
            top=5.2)

    # SLIDE — Database in detail
    s = content_slide(prs, layouts, "Database — Services in Detail")
    add_table(s,
        ["Svc", "What It Is", "When to Use", "Check First"],
        [
            ["RDS", "Managed relational DB (MySQL, PG)",
             "Apps using standard SQL",
             "Slow log, connections, HA status"],
            ["GaussDB", "Huawei high-performance database",
             "Large scale, OLTP workloads",
             "Performance, sync, connections"],
            ["DRS", "Data replication and migration",
             "DB migration, continuous sync",
             "Sync lag, job status"],
            ["DDS", "Document database (NoSQL)",
             "Apps with flexible schema",
             "Slow queries, indexes, connections"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'tip',
            "RDS is the most used DB. Common issues: slow queries and connection limits. "
            "Always ask for the slow log and active connection count.",
            top=5.2)

    # SLIDE — Security in detail
    s = content_slide(prs, layouts, "Security — Services in Detail")
    add_table(s,
        ["Svc", "What It Is", "When to Use", "Check First"],
        [
            ["Anti-DDoS", "Protection against denial-of-service",
             "Public-facing exposed services",
             "Abnormal traffic, attack event"],
            ["WAF", "Web application firewall",
             "Websites and web APIs",
             "WAF rules, false positives, logs"],
            ["IAM", "Identity and access management",
             "All services",
             "Policies, roles, permissions"],
            ["KMS", "Encryption key management",
             "Sensitive data, compliance",
             "Key exists? Usage permission?"],
        ],
        col_widths=[Inches(0.8), Inches(3.5), Inches(3.2), Inches(4.2)])
    callout(s, 'warning',
            "Never ask for customer credentials. For access issues, "
            "check the IAM policy and guide the customer to verify permissions.",
            top=5.2)

    # SLIDE — Hotline Quick Reference
    s = content_slide(prs, layouts, "Quick Reference — Hotline by Family")
    add_table(s,
        ["Family", "First Thing to Check", "Escalate When"],
        [
            ["Compute", "VM status, quotas, system events",
             "Won't boot after basic checks"],
            ["Storage", "Capacity, IOPS, disk attachment",
             "Data loss risk"],
            ["Network", "VPC, Security Group, EIP, routes",
             "Total connectivity loss"],
            ["Database", "Slow log, connections, HA status",
             "Data corruption or HA failover"],
            ["Security", "IAM policy, WAF rules, traffic",
             "Active attack or total block"],
        ],
        col_widths=[Inches(1.8), Inches(5.5), Inches(4.4)])
    callout(s, 'tip',
            "This table is your pocket guide. Before escalating any SR, "
            "always run through the middle-column checks first.",
            top=5.2)

    # SLIDE — Key Acronyms (no Full Name column)
    s = content_slide(prs, layouts, "Key Acronyms")
    add_table(s,
        ["Acronym", "Description"],
        [
            ["ECS", "Elastic Cloud Server — scalable virtual server"],
            ["EVS", "Elastic Volume Service — elastic block storage"],
            ["VPC", "Virtual Private Cloud — isolated virtual network"],
            ["ELB", "Elastic Load Balance — load balancer"],
            ["RDS", "Relational Database Service — managed relational DB"],
            ["OBS", "Object Storage Service — object storage"],
            ["IAM", "Identity & Access Management — identity management"],
            ["SR", "Service Request — service ticket"],
            ["ITR", "Issue To Resolve — incident to resolution"],
            ["TAC", "Technical Assistance Center — technical support center"],
        ],
        col_widths=[Inches(1.5), Inches(10.2)])

    # SLIDE — Naming Convention
    s = content_slide(prs, layouts, "Naming Convention")
    text_box(s,
        "Rules for resource names in HCS:\n\n"
        "  • VMs: [project]-[role]-[seq]    (e.g: billing-app-01)\n"
        "  • Volumes: [vm]-[disk]-[seq]     (e.g: billing-app-disk-01)\n"
        "  • VPCs: [region]-[env]-vpc       (e.g: sa-east-1-prod-vpc)\n"
        "  • SRs: SR-[year][month][seq]     (e.g: SR-202609-00123)\n\n"
        "Validation: always confirm the exact resource name before proceeding.",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 3 — SR Process
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "SR Opening Process",
                  "From customer email to resolution")

    # SLIDE — SR Flow (flowchart)
    s = content_slide(prs, layouts, "SR Process Flow")
    flowchart_vertical(s, [
        {'text': 'Receive SR (customer email)', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'text': 'Validate identity and contract', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'text': 'Classify severity (S1-S4)', 'fill': RGBColor(0xFD, 0xF8, 0xEE)},
        {'type': 'arrow'},
        {'text': 'Send email to TAC Team', 'fill': RGBColor(0xED, 0xF6, 0xED), 'bold': True},
        {'type': 'arrow'},
        {'text': 'Diagnose and resolve', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'text': 'Verify and close SR', 'fill': GRAY_BG},
    ], left=4.5, top=TOP_CONTENT + 0.1, box_width=4.0, box_height=0.45, gap=0.2)

    # SLIDE — TAC Email
    s = content_slide(prs, layouts, "TAC Team Notification")
    callout(s, 'warning',
            "MANDATORY: when opening any SR, send an email to the TAC Team "
            "using the official SR template.",
            top=TOP_CONTENT + 0.1)
    text_box(s,
        "SR Template (required fields):\n\n"
        "  • SR number\n"
        "  • Customer and site\n"
        "  • Severity (S1/S2/S3/S4)\n"
        "  • Affected service (official name)\n"
        "  • Problem description\n"
        "  • Business impact\n"
        "  • Maintenance window (if applicable)\n"
        "  • Responsible contact",
        Inches(LEFT_MARGIN), Inches(3.2),
        Inches(CONTENT_WIDTH), Inches(3.5), 13, DARK)

    # SLIDE — Mailbox / Email
    s = content_slide(prs, layouts, "Email Reception")
    text_box(s,
        "Current flow:\n"
        "  Customer sends email -> hotline receives and opens SR\n\n"
        "Future (in transition):\n"
        "  Emails arrive via dedicated mailbox -> automatic triage\n\n"
        "Regardless of the intake channel, the process is the same:\n"
        "  1. Validate requester\n"
        "  2. Open SR in the system\n"
        "  3. Notify TAC Team\n"
        "  4. Assign owner",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)
    callout(s, 'tip',
            "Always validate the caller identity against the authorized contact list.",
            top=5.5)

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 4 — ITR Process
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "ITR Process (Issue To Resolve)",
                  "From triage to closure")

    # SLIDE — ITR Flow (flowchart with decisions)
    s = content_slide(prs, layouts, "ITR Flow with Escalation")
    flowchart_vertical(s, [
        {'text': 'Incident Reported', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'text': 'L1 Triage', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'type': 'decision', 'text': 'L1 resolves?'},
    ], left=1.5, top=TOP_CONTENT + 0.1, box_width=2.5, box_height=0.5, gap=0.25)

    flow_box(s, "Escalate to L2", 5.0, 3.3, 2.5, 0.5,
             fill=RGBColor(0xFD, 0xF8, 0xEE), bold=True)
    flow_arrow(s, 4.0, 3.45, 0.5, 0.3, direction='right')

    flowchart_vertical(s, [
        {'type': 'arrow'},
        {'text': 'L2 Investigates', 'fill': GRAY_BG},
        {'type': 'arrow'},
        {'type': 'decision', 'text': 'L2 resolves?'},
    ], left=5.0, top=3.8, box_width=2.5, box_height=0.5, gap=0.25)

    flow_box(s, "Escalate L3/R&D", 8.5, 5.0, 2.5, 0.5,
             fill=RGBColor(0xFD, 0xF8, 0xEE), bold=True)
    flow_arrow(s, 7.5, 5.15, 0.5, 0.3, direction='right')

    flow_box(s, "Resolve & Close ITR", 4.5, 6.0, 4.0, 0.5,
             fill=RGBColor(0xED, 0xF6, 0xED), bold=True)

    # SLIDE — Escalation Matrix
    s = content_slide(prs, layouts, "Escalation Matrix")
    add_table(s,
        ["Level", "Owner", "SLA", "When to Escalate"],
        [
            ["L1", "Hotline", "15 min", "Issue not identified"],
            ["L2", "Specialist", "1h", "L1 cannot resolve in 30 min"],
            ["L3", "Product Eng.", "4h", "Bug or complex config"],
            ["R&D", "Development", "24h", "Confirmed product bug"],
        ])
    callout(s, 'warning',
            "S1 (critical): escalate immediately to L2 when opening the SR.",
            top=5.0)

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 5 — Common Operations
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "Common O&M Operations",
                  "Monitoring, issues and solutions")

    # SLIDE — Monitoring
    s = content_slide(prs, layouts, "Monitoring and Alerts")
    text_box(s,
        "HCS monitoring tools:\n\n"
        "  • ManageOne Operation — health dashboards\n"
        "  • AOM (Application Operations Management) — app metrics\n"
        "  • APM (Application Performance Monitoring) — traces\n"
        "  • CloudEye — infrastructure monitoring\n\n"
        "Common alerts:\n"
        "  • CPU > 80% for 5 min -> check workloads\n"
        "  • Disk > 90% -> check logs and snapshots\n"
        "  • Memory > 85% -> check for leaks\n"
        "  • Network latency > 100ms -> check VPC/ELB",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 13, DARK)

    # SLIDE — Common Issues
    s = content_slide(prs, layouts, "Common Issues and Quick Fixes")
    add_table(s,
        ["Issue", "Symptom", "Quick Action"],
        [
            ["VM won't boot", "Status: ERROR", "Check quotas, disk, network"],
            ["Disk full", "Alert > 90%", "Clean logs, expand EVS"],
            ["No network", "Ping fails", "Check VPC, EIP, SG"],
            ["ELB unhealthy", "Backend down", "Check health check, port"],
            ["RDS slow", "Query timeout", "Check slow log, indexes"],
            ["OBS 403", "Access denied", "Check AK/SK, IAM policy"],
        ])

    # ═══════════════════════════════════════════════════════════════
    # CHAPTER 6 — Best Practices
    # ═══════════════════════════════════════════════════════════════
    chapter_slide(prs, layouts, "Best Practices",
                  "Checklist and resources")

    # SLIDE — Do's and Don'ts
    s = content_slide(prs, layouts, "Do's and Don'ts")
    callout(s, 'warning',
            "Never ask for or accept customer credentials. "
            "Guide them to self-service.",
            top=TOP_CONTENT + 0.1)
    callout(s, 'tip',
            "Always confirm the exact service and resource name before proceeding.",
            top=TOP_CONTENT + 1.0)
    callout(s, 'infobox',
            "Document every troubleshooting step in the SR for traceability.",
            top=TOP_CONTENT + 1.9)
    callout(s, 'warning',
            "Do not apply workarounds in production without an approved maintenance window.",
            top=TOP_CONTENT + 2.8)
    callout(s, 'tip',
            "Use the official SR template when notifying the TAC Team.",
            top=TOP_CONTENT + 3.7)

    # SLIDE — Self-Service Resources
    s = content_slide(prs, layouts, "Self-Service Resources")
    text_box(s,
        "Direct customers to:\n\n"
        "  • ServiceCenter — self-service portal\n"
        "  • HCS Documentation — docs.huaweicloud.com\n"
        "  • Knowledge Base — troubleshooting articles\n"
        "  • Status Page — service status\n"
        "  • Forum — technical community\n\n"
        "Benefits:\n"
        "  • Reduces low-severity SR volume\n"
        "  • Customer resolves faster\n"
        "  • Hotline focuses on S1/S2",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)

    # SLIDE — Validation Checklist
    s = content_slide(prs, layouts, "SR Validation Checklist")
    text_box(s,
        "Before closing any SR, validate:\n\n"
        "  [ ] Requester identity confirmed\n"
        "  [ ] Official service name identified\n"
        "  [ ] Severity correctly classified\n"
        "  [ ] TAC Team notified with template\n"
        "  [ ] Diagnosis documented in SR\n"
        "  [ ] Solution applied and verified\n"
        "  [ ] Customer confirmed resolution\n"
        "  [ ] SR closed with resolution documented\n"
        "  [ ] Lessons learned recorded (if applicable)",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)

    # SLIDE — Next Steps
    s = content_slide(prs, layouts, "Next Steps")
    text_box(s,
        "Goal: team authoring content starting 09/01\n\n"
        "Preparation required:\n"
        "  1. Review this complete training\n"
        "  2. Practice opening SRs with template\n"
        "  3. Familiarize with ManageOne and ServiceCenter\n"
        "  4. Study ITR flows and escalation matrix\n"
        "  5. Know acronyms and service families\n\n"
        "Target stack: HCS 8.6.1",
        Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
        Inches(CONTENT_WIDTH), Inches(4.5), 14, DARK)
    callout(s, 'tip',
            "Questions? Check the escalation matrix or escalate to L2.",
            top=5.8)

    # ═══════════════════════════════════════════════════════════════
    # LAST SLIDE
    # ═══════════════════════════════════════════════════════════════
    last_slide(prs, layouts)

    path = save_deck(prs, os.path.join(OUT_DIR, "sample-en.pptx"))
    print(f"Saved: {path}")


if __name__ == "__main__":
    main()
