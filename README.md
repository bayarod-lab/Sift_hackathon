# 🕵️‍♂️ ATP: Autonomous DFIR Triage Pipeline (Hackathon Prototype)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📋 Official Hackathon Compliance Checklist
As requested by the organizers, the following components are included in this submission:
- [x] **Code Repository:** Public repository with MIT License included.
- [x] **Setup Instructions:** Provided in Section 3 below.
- [x] **Execution/Deployment Instructions:** Provided in Section 4 below.
- [x] **Text Description:** Provided in Section 1 (Features & Functionality).
- [x] **Demonstration Video:** Link provided in the header.
- [x] **Architecture Diagram:** Provided in Section 2.
- [x] **Evidence Dataset Documentation:** See [EVIDENCE.md](EVIDENCE.md)
- [x] **Accuracy Report:** See [ACCURACY_REPORT.md](ACCURACY_REPORT.md)
- [x] **Agent Execution Logs:** Provided in Section 7 below.

**Elevator Pitch:** An experimental proof-of-concept orchestrator that automates the initial "first pass" of digital evidence triage using strict read-only constraints. Built for the SANS FIND EVIL Hackathon 2026.

### 🔗 Official Submission Links
* **Devpost Project Page:** [Insert Devpost URL Here]
* **Demonstration Video:** [https://youtu.be/aQvzBe00tM8] 
* **GitHub Repository:** [https://github.com/bayarod-lab/Sift_hackathon](https://github.com/bayarod-lab/Sift_hackathon) 

--- 

## 🏗️ Architecture & Classification Strategy

![Architecture Diagram](docs/Diagram.png)

This orchestrator executes under an **Alternative Agentic IDE** pattern (utilizing Aider). Evidence integrity is enforced via strict architectural isolation layers rather than soft prompt controls. The LLM is completely isolated from the raw evidence. 

The bash orchestrator (`analyze.sh`) extracts data using OS-level SIFT tools (`fls`, `ewfmount`, `7z`, `tshark`), dumps the output into truncated text files, and uses Aider's `--read` flag to create a hard boundary. The original forensic data blocks remain completely read-only, ensuring zero spoliation even if the model hallucinates or fails.

---

## 🚀 Key Features & Functionality

* **Read-Only Confinement:** The AI never executes shell commands. It acts strictly as a text-parsing and correlation engine over pre-extracted SIFT utility outputs.
* **Hybrid Capability Discovery:** Queries the active AI model via `litellm`. If it detects a model with a larger context window (e.g., `gemini-3.5-flash`), it dynamically increases the `head -n` extraction limits up to 5,000 lines.
* **API Rate-Limit Guardrails:** Separates execution speed from the model type. Users on free API tiers are protected by automated 45-second fallback cooldown buffers to proactively block `429 Resource Exhausted` errors.
* **Multi-Pass "Peer Review":** Ingestion tasks map across distinct logical levels. An initial loop extracts IOCs, a second builds the ledger, and a third spawns a "Senior Forensic Review" prompt that critiques the raw findings, flags unsupported MITRE mappings, and forces a self-correction pass.
* **Basic Schema Validation:** Uses programmatic Python validation paired with regex (`sed`) to automatically strip out LLM markdown pollution or broken JSON structures, forcing retries if the schema breaks.
* **Deterministic OSINT Integration:** Automatically scrapes extracted MD5/SHA256 hashes and queries the VirusTotal API (`check_hashes.py`) to inject confirmed cryptographic threat intelligence directly into the AI's fact graph prior to analysis[cite: 3].
* **Adversarial Hunt Pass:** Executes a specialized `Pass 1.D` agent explicitly instructed to hunt for high-severity MITRE TTPs (e.g., DLL sideloading, double extensions, masqueraded system binaries) to counter the AI's baseline null-hypothesis bias during the final correlation phase[cite: 3].
* **Automated Network Parsing:** Detects `.pcap` and `.pcapng` telemetry targets and autonomously streams protocol hierarchies, DNS queries, and TLS SNI artifacts via `tshark` directly into the agent's context window[cite: 3].

---

## ⚠️ Known Limitations (Hackathon Prototype Realities)

* **Data Truncation Blindspots:** To prevent token-limit blowouts, the script aggressively truncates raw evidence files (capping string dumps at 1,500 - 5,000 lines depending on the model). Deeply hidden malware will be missed.
* **Encoding Artifacts:** Complex file paths or non-standard character encodings (e.g., UTF-16/Chinese characters) in raw extractions can occasionally cause mojibake in the final PDF output.
* **False Positives:** While heuristic filtering is in place to ignore standard domains (like `google.com`), the pipeline may still flag benign administrative tools or local file shortcuts as suspicious if contextual network telemetry is missing.

---

## ⚙️ Prerequisites & Setup Instructions

This platform is optimized for native Linux environments and purpose-built for the SANS SIFT Workstation.

### 1. Ingest System Dependencies
Ensure you have Python 3 installed. Install the background forensic utilities, compression layouts, and PDF rendering backends required by your host system:

Bash
sudo apt-get update && sudo apt-get install -y python3-weasyprint pango1.0-tools p7zip-full ewf-tools sleuthkit
2. Clone the Repository
Bash
git clone [https://github.com/bayarod-lab/Sift_hackathon.git](https://github.com/bayarod-lab/Sift_hackathon.git)
cd Sift_hackathon
3. Install Package Frameworks
Install the corresponding underlying Python reporting and agentic automation scripts:

Bash
pip3 install weasyprint aider-chat litellm
4. Configure Authentication & Workspace Parameters
Export your variables and testing configurations directly into your open shell session.
(Note for Judges: You must supply a valid Google AI Studio API key with internet access to run the cognitive reasoning engine locally).

Bash
# Set your active Google AI Studio Key
export GEMINI_API_KEY="your-api-key"

# [Optional Override] Set your target execution model (Defaults to gemini-3.1-flash-lite)
export AI_MODEL="gemini/gemini-3.5-flash"

# [Optional Override] Scale performance parameters by designating billing profile (FREE or PAID)
export API_TIER="FREE"

# [Optional] Set VirusTotal API Key for cryptographic hash reputation checks
export VT_API_KEY="your-vt-key"
🚀 Usage Guide (Local Execution)
The triage workspace executes via a single orchestrator loop. Pass your direct path vector target as an input parameter argument.

To execute analysis on standard VIGÍA telemetry cases:

Bash
./analyze.sh "reference_material/telemetry_source.json"
To process a compressed forensic archive matrix (e.g., memory dumps or triaged collections):

Bash
./analyze.sh "evidence/Rocba-Memory.zip"
To handle raw disk capture structures (E01) via automated mount logic:

Bash
sudo -E ./analyze.sh "evidence/rocba-cdrive.e01"
(Note: Executing against .e01 elements requires passing sudo -E to provide structural device mounting permissions while cleanly maintaining your environmental variables for the AI engine).

📜 Audit & Execution Logs
All automated workflows enforce an append-only transaction layer. Judges can trace any finding back to the specific iteration-over-iteration trace that produced it, complete with estimated token tracking.

Tool Execution & Token Tracking: cases/INC-2026-[CASE_NAME]/actions.jsonl

Cryptographic Intake Hashes: cases/INC-2026-[CASE_NAME]/chain_of_custody.txt

Agent-to-Agent Logic Critiques: cases/INC-2026-[CASE_NAME]/critique.txt

Final Verified Forensic Ledger: cases/INC-2026-[CASE_NAME]/triage_ledger.json

⚖️ License
This pipeline framework is open-source distribution software covered under the provisions of the MIT License.
