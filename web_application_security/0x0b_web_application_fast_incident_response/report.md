# Incident Report: Denial of Service (DoS) Attack Analysis and Remediation

## 1. Introduction
This report details the investigation into a **Denial of Service (DoS)** attack that occurred on June 14, 2024. The attack targeted the root endpoint of the web application, resulting in a massive surge of automated traffic that compromised server stability and led to internal server errors. The purpose of this report is to analyze the attack vectors and propose a comprehensive mitigation strategy to prevent future service disruptions.

## 2. Detailed Attack Analysis
Based on the analysis of the system logs (`logs.txt`), the following attack characteristics were identified:

*   **Attack Source:** The vast majority of the malicious traffic originated from a single IP address: **54.145.34.34**.
*   **Targeted Endpoint:** The attack was directed exclusively at the root URL (`/`).
*   **Request Method:** The attacker utilized **POST** requests, which are more resource-intensive for the server to process compared to GET requests.
*   **Request Volume:** Approximately **5,000 requests** were sent from the malicious source in a very short time window (from 17:26:35 to 17:28:47).
*   **Tools Used:** The User-Agent string identified the tool as **python-requests/2.31.0**, confirming the use of an automated Python script to generate traffic.
*   **Impact:** At the height of the attack (17:28:20), the server began returning **500 Internal Server Error** codes, indicating that the backend (uWSGI/Database) was unable to handle the load.

## 3. Proposed Mitigation Strategy
To protect the server and ensure high availability, the following multi-layered mitigation plan is proposed:

1.  **Rate Limiting (Primary Solution):** Implement request throttling at the Nginx level to limit the number of requests a single IP can make within a specific timeframe.
2.  **IP-Based Blocking:** Use a firewall (iptables/ufw) or a web application firewall (WAF) to permanently or temporarily block IP 54.145.34.34.
3.  **User-Agent Filtering:** Block requests originating from non-browser automation libraries like `python-requests` if they are not required for legitimate API usage.
4.  **System Hardening:** Address identified configuration weaknesses, such as running processes as root and missing authentication.

## 4. Justification for the Proposed Solution
**Rate Limiting** is the industry standard for preventing application-layer DoS attacks. It ensures that no single user can monopolize server resources (CPU, Memory, DB connections), thereby preserving service quality for legitimate users. Furthermore, hardening the **Supervisor** configuration is essential to follow the **Principle of Least Privilege**, reducing the potential impact if a process is compromised.

## 5. Steps for Implementation

### A. Configure Nginx Rate Limiting
Modify the `nginx.conf` to define a rate-limiting zone and apply it to the targeted location:
```nginx
http {
    # Define a zone that allows 5 requests per second per IP
    limit_req_zone $binary_remote_addr zone=mylimit:10m rate=5r/s;

    server {
        location / {
            # Apply the limit with a burst of 10 requests
            limit_req zone=mylimit burst=10 nodelay;
            ...
        }
    }
}
```

### B. Secure Supervisor and HTTP Server
1.  Update the Supervisor configuration file to specify a non-root user (e.g., `user=www-data`).
2.  Enable HTTP authentication for the `unix_http_server` to prevent unauthorized RPC interface access.

### C. Deploy Fail2Ban
Install and configure **Fail2Ban** to automatically scan logs for repeated rate-limit violations and trigger temporary IP bans at the firewall level.

## 6. Post-Implementation Monitoring
Ongoing security posture will be maintained through:
*   **Real-time Log Analysis:** Monitoring Nginx access logs for 429 (Too Many Requests) and 5xx errors to identify new attack patterns.
*   **Traffic Metrics:** Utilizing dashboards (e.g., Prometheus/Grafana) to visualize request rates per IP.
*   **Automated Alerts:** Setting up notifications for when request thresholds are exceeded or when Fail2Ban executes a ban.

## 7. Conclusion
The analyzed incident was a high-volume automated DoS attack that successfully overwhelmed server resources. Implementing **Rate Limiting** is the most effective way to limit server usage per client and prevent such incidents from recurring. Combined with system hardening and proactive monitoring, these measures will significantly enhance the organization's defensive capabilities against future web application threats.
