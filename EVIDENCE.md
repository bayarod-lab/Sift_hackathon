# Evidence Dataset Documentation

This pipeline was rigorously tested against diverse forensic data sources to document agent versatility, extraction capability, and cognitive reasoning constraints.

### 1. ROCBA Dataset (Disk & Memory)
*   **Source of Data:** Hackathon standalone forensic dataset (`rocba-cdrive.e01` and `Rocba-Memory.zip`).
*   **What it was tested against:** Full Windows 10 logical disk image (22GB) and raw memory dump (5GB).
*   **What the Agent Found:** 
    *   **Disk:** Identified standard user workstation activity, mapping common productivity applications (Skype, Slack, iCloud) and correctly establishing a benign system baseline.
    *   **Memory:** Processed via `run_scan.py` (Volatility 3 `windows.pstree`), parsed the raw text dump, and identified anomalous circular parentage loops between `Teams.exe` instances and an execution of `smartscreen.exe` lacking an executable path.
*   **Verdict:** Dynamic (`BENIGN` for Disk, `MALICIOUS` for Memory).

### 2. VANKO Dataset (`surface_physical`)
*   **Source of Data:** Hackathon provided scenario data (`VANKO.zip`).
*   **What it was tested against:** Segmented physical disk image sequence (`surface_physical.E01` through `.E21`) mapping to a Windows Surface device.
*   **What the Agent Found:** Analyzed the `defaultprinter` user profile. The agent successfully identified the staging of dual-use secure deletion utilities (SDelete), anonymity tools (Tor Browser), and access to highly sensitive intellectual property documents. Crucially, the agent restrained its execution confidence, correctly refusing to hallucinate data exfiltration without network logs.
*   **Verdict:** `INCONCLUSIVE` / `POLICY VIOLATION`

### 3. VIGIA-REAL Datasets (Cases 001 - 010)
*   **Source of Data:** Public DFIR datasets (including NIST CFReDS and Ali Hadi challenges) standardized via the VIGÍA Canonical Format.
*   **What it was tested against:** A vast array of structured JSON telemetry covering Registry, Network Flow, Filesystem Metadata, and Auth Logs.
*   **What the Agent Found:** The pipeline was validated against 10 distinct, real-world attack scenarios. Highlights include:
    *   **Case 001 (War Driving):** Identified threat actor aliases, NetStumbler executables, and intercepted PCAP data.
    *   **Case 002 (Insider Threat):** Mapped an "Evasion Accountability" sequence involving external conspirator emails, personal Gmail exfiltration, and CCleaner anti-forensic deployment.
    *   **Case 003 (Web Exploitation):** Traced DVWA SQL injection attacks, PHP webshell deployments (`tmpukudk.php`), and unauthorized local account creation.
    *   **Case 005 (False Positive Trap):** Correctly reasoned that multiple layers of encryption (BitLocker/GPG) without active exploit payloads constituted privacy concealment rather than active malware.
*   **Verdict:** Consistently accurate across all 10 benchmarks, successfully scaling semantic evaluations across `MALICIOUS`, `SUSPICION`, and `BENIGN` ground-truth keys.
