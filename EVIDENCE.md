# Evidence Dataset Documentation

This pipeline was rigorously tested against three distinct data sources to document exactly what the agent was tested against, the source of the data, and what the agent found.[cite: 17]

### 1. VIGIA-REAL-001 (NIST CFReDS - Hacking Case)
*   **Source of Data:** Public NIST CFReDS dataset via VIGÍA Canonical Format.[cite: 17]
*   **What it was tested against:** Structured JSON Telemetry (Registry, Network, Files).[cite: 17]
*   **What the Agent Found:** The agent successfully identified the threat actor's real name (Greg Schardt), hacking alias (Mr. Evil), war-driving executables (NetStumbler), and credential theft via intercepted PCAP data.[cite: 17]
*   **Verdict:** `MALICIOUS`[cite: 17]

### 2. VIGIA-REAL-005 (Ali Hadi - False Positive Trap)
*   **Source of Data:** Ali Hadi challenges via VIGÍA Canonical Format.[cite: 17]
*   **What it was tested against:** Structured JSON Telemetry.[cite: 17]
*   **What the Agent Found:** The agent mapped multiple layers of encryption (AES file concealment, BitLocker volume 'R2D2', and GPG/PGP keys). Crucially, the agent correctly reasoned that without an active exploit payload or exfiltration, this was privacy-focused concealment, not active malware.[cite: 17]
*   **Verdict:** `SUSPICION`[cite: 17]

### 3. Rocba-Memory_2.raw (Process Injection)
*   **Source of Data:** Hackathon standalone memory dump.[cite: 17]
*   **What it was tested against:** Unstructured `.raw` binary.[cite: 17]
*   **What the Agent Found:** Processed via `run_scan.py` (Volatility 3 `windows.pstree`), the agent parsed the raw text dump and identified an anomalous circular parentage loop between `Teams.exe` instances and an execution of `smartscreen.exe` lacking an executable path.[cite: 17]
*   **Verdict:** `MALICIOUS`[cite: 17]
