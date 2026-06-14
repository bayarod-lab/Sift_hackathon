Here are your updated project documents, revised to explicitly satisfy the Hackathon requirements. The formatting has been aligned to ensure judges can immediately see that you hit every rubric criteria.

1. Updated README.md
Markdown
# 🕵️‍♂️ ATP: Autonomous DFIR Triage Pipeline
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Elevator Pitch:** An autonomous, multi-agent DFIR orchestrator that dynamically scales to your AI model's power for rapid, defensible evidence triage. Built for the SANS FIND EVIL Hackathon 2026.

### 🔗 Official Submission Links
* **Devpost Project Page:** [Insert Devpost URL Here]
* **Demonstration Video:** [Insert YouTube, Vimeo, or Youku URL Here] 
  * *Note: The video is under five (5) minutes and features a screencast of live terminal execution with audio narration, showcasing the agent working against real evidence and completing a self-correction sequence. It contains no copyrighted music or third-party trademarks.*
* **GitHub Repository:** [https://github.com/bayarod-lab/Sift_hackathon](https://github.com/bayarod-lab/Sift_hackathon)[cite: 18] *(Ensure the MIT License is visible at the top of the repository page in the About section).*

---

## 🏗️ Architecture Diagram

![Architecture Diagram](docs/architecture.png)[cite: 18]

**Classification Architecture Strategy:** 
This orchestrator executes under an **Alternative Agentic IDE** pattern (utilizing Aider). A clear visual showing how components connect—the agent, SIFT tools, MCP servers, evidence sources, and output pipeline—is provided above. Evidence integrity is enforced via strict architectural isolation layers (OS-level decoupled extraction via `fls`/`ewfmount`/`7z`) rather than soft prompt controls. The Aider `--read` flag creates a hard boundary, ensuring original forensic data blocks remain completely read-only even if an intermediate model execution fails.

---

## 🚀 Key Features & Functionality

* **Hybrid Capability Discovery Engine:** A real-world systems utility that queries your active AI model's footprint via `litellm`. If the underlying platform reveals a next-generation architecture (such as `gemini-3.5-flash`), it expands the context processing ceiling up to 1,000 log lines per asset file.
* **Dual-Decoupled Account Guardrails:** The pipeline separates model strength from your active account quota billing tier. Users running state-of-the-art models via free API keys are protected by an automated 45-second fallback cooldown buffer to proactively block `429 Resource Exhausted` errors.
* **Phase-Aware Multi-Agent Peer Review Loops:** Ingestion tasks map across distinct logical levels. An initial staging loop sets basic telemetry criteria, followed by a Senior Forensic Review Loop that systematically critiques the raw file systems, flags hidden attribution anomalies, identifies evasion tactics, and writes independent `critique.txt` audit summaries.
* **Self-Healing Schema Guardrails:** Implements programmatic validation loops paired with regex string cleaners (`sed`). If a model attempts to introduce UI progress meters or markdown block pollution, the system intercepts the hallucination and guides automated script self-corrections.
* **Defensive Specificity Calibration:** Prompt criteria prioritize forensic fidelity. The pipeline explicitly handles dual-use system elements (like disk encryption matrices or network monitoring installations) as baseline exceptions, demanding objective context indicators before jumping to malicious threat assumptions.

---

## ⚙️ Prerequisites & Step-by-Step Setup Instructions

This platform is optimized for seamless deployment inside native Linux environments and purpose-built for the SANS SIFT Workstation platform. These step-by-step instructions allow judges to run the agent locally against provided evidence.

### 1. Ingest System Dependencies
Ensure you have Python 3 installed. Install the background forensic utilities, compression layouts, and PDF rendering backends required by your host system:

```bash
sudo apt-get update && sudo apt-get install -y python3-weasyprint pango1.0-tools p7zip-full ewf-tools sleuthkit
2. Clone the Repository
Bash
git clone [https://github.com/bayarod-lab/Sift_hackathon.git](https://github.com/bayarod-lab/Sift_hackathon.git)
cd Sift_hackathon
3. Install Package Frameworks
Install the corresponding underlying Python reporting and agentic automation scripts:  
MD

Bash
pip3 install weasyprint aider-chat litellm
4. Configure Authentication & Workspace Parameters
The analytical pipeline queries Gemini API environments for core automated reasoning steps. Export your variables along with your choice of testing configurations directly into your open shell session.[cite: 18]

Note for Judges: You must supply a valid Google AI Studio API key with internet access to run the cognitive reasoning engine locally.

[cite: 18]

Bash
# Set your active Google AI Studio Key
export GEMINI_API_KEY="your-api-key"

# [Optional Override] Set your target execution model (Defaults to gemini-3.1-flash-lite)
export AI_MODEL="gemini/gemini-3.5-flash"

# [Optional Override] Scale performance parameters by designating billing profile (FREE or PAID)
export API_TIER="FREE"
🚀 Usage Guide (Local Execution)
The triage workspace executes via a single orchestrator loop. Simply pass your direct path vector target as an input parameter argument.[cite: 18]

To execute analysis on standard VIGÍA telemetry cases:

Bash
./analyze.sh "reference_material/telemetry_source.json"
To process a compressed forensic archive matrix (such as the ROCBA triage dataset):

Bash
./analyze.sh "evidence/Rocba-Memory.zip"
To handle raw disk capture structures or EnCase split collections via automated mount logic:

Bash
sudo -E ./analyze.sh "evidence/rocba-cdrive.e01"
(Note: Executing against .e01 elements requires passing sudo -E flags to provide structural device mounting permissions while cleanly maintaining your environmental variables for the automated engine).

[cite: 18]

📜 Agent Execution Logs
All automated workflows enforce an append-only transaction layer. Structured logs showing the full agent communication, tool execution sequence, and multi-agent peer review steps are captured. Judges can trace any finding back to the specific iteration-over-iteration trace that produced it.[cite: 18] The system ran successfully against the VIGIA-REAL-001 dataset, and the verified logs with timestamps and agent-to-agent messages are directly accessible below:

Tool Execution & Timestamp Logs: cases/INC-2026-case/actions.jsonl

[cite: 18]

Agent-to-Agent Message Logs (Iteration Traces): cases/INC-2026-case/critique.txt

[cite: 18]

Final Verified Forensic Ledger: cases/INC-2026-case/triage_ledger.json

[cite: 18]

⚖️ License
This pipeline framework is open-source distribution software covered under the provisions of the MIT License.[cite: 18]
