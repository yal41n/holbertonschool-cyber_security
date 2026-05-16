# Task 1: CVE Severity and Organizational Prioritization

## 1. How CVE Severity Affects Prioritization

Modern enterprise networks are flooded with thousands of vulnerability alerts daily. If a security team attempted to fix every single bug simultaneously, operations would grind to a halt. **CVE Severity**—typically determined by the **CVSS (Common Vulnerability Scoring System)** score ranging from 0.0 to 10.0—acts as a triage mechanism. 

It allows organizations to shift from a reactive "fix everything" mindset to a proactive, risk-based strategy. Severity scores help security operations centers (SOCs) and IT administrators calculate the **Window of Exposure** and allocate limited resources (manpower, testing time, and network downtime) to where they are needed most.

---

## 2. Severity Levels and Response Strategies

Organizations establish **Service Level Agreements (SLAs)** based on CVE severity levels. Below is a breakdown of how different severity levels dictate real-world response strategies:

### 🚨 Critical Severity (CVSS 9.0 – 10.0)
* **Characteristics**: Vulnerabilities that can be exploited remotely without authentication, requiring zero user interaction. They often result in full system takeover or wormable root access.
* **Response Strategy**: **Emergency / Out-of-Band Action**. Security teams drop routine tasks. Patching happens immediately (typically within 24 to 48 hours), bypassing the standard monthly maintenance window.
* **Example/Scenario**: A remote code execution (RCE) flaw in a public-facing web server firewall. If unpatched, ransomware can automate entry within hours.

### 🟠 High Severity (CVSS 7.0 – 8.9)
* **Characteristics**: Exploitation is highly likely and damaging, but may require some basic preconditions, such as standard user privileges or specific network positioning.
* **Response Strategy**: **Expedited Patching**. These flaws are scheduled for remediation within a strict, accelerated timeframe (usually 7 to 14 days). Temporary mitigations (like adjusting firewall rules) are deployed if an immediate patch isn't possible.
* **Example/Scenario**: A local privilege escalation flaw that allows a standard corporate user to become a Domain Administrator.

### 🟡 Medium Severity (CVSS 4.0 – 6.9)
* **Characteristics**: Exploitation requires complex conditions, significant user interaction (e.g., advanced phishing), or physical access to the machine. The impact is localized rather than systemic.
* **Response Strategy**: **Routine Maintenance**. These are handled during standard, pre-scheduled patch cycles (e.g., "Patch Tuesday" or monthly maintenance windows), usually within 30 to 60 days.
* **Example/Scenario**: A Cross-Site Scripting (XSS) vulnerability on an internal company portal that requires a user to click a highly specific, modified link.

### 🔵 Low Severity (CVSS 0.1 – 3.9)
* **Characteristics**: Extremely difficult to exploit, yielding minimal impact (e.g., leaking non-sensitive system information like software version numbers).
* **Response Strategy**: **Monitor and Log**. These are fixed during major system upgrades or left as a accepted residual risk. They are logged in the asset inventory but rarely warrant dedicated emergency labor.
* **Example/Scenario**: A component that reveals the exact patch sub-version of a backend database to an authenticated user.

---

## 3. Operational Summary Table

| Severity Level | CVSS Score Range | Operational Priority | Typical Patch SLA | Example Action Plan |
| :--- | :--- | :--- | :--- | :--- |
| **Critical** | 9.0 – 10.0 | Immediate Emergency | 24 - 48 Hours | Isolate server, apply emergency vendor patch out-of-band. |
| **High** | 7.0 – 8.9 | High Priority | 7 - 14 Days | Schedule patch for the upcoming weekend; monitor logs closely. |
| **Medium** | 4.0 – 6.9 | Routine | 30 - 60 Days | Apply fix during the standard monthly maintenance cycle. |
| **Low** | 0.1 – 3.9 | Low Priority | Next Major Lifecycle | Log the issue; address during the next total system overhaul. |
