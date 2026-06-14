# Accuracy Report & Self-Assessment

In accordance with Hackathon rules, this is an honest self-assessment of the agent's accuracy, detailing the false positives, missed artifacts, and hallucinated claims identified during testing, alongside subsequent architectural corrections.[cite: 16] Honesty is valued over perfection.

### 1. Hallucinated Claims: The "Execution Pipe" Bypass
**Issue:** Early iterations of the agent lacked direct access to an MCP server. When instructed to scan memory, it hallucinated terminal commands (e.g., `echo {...} | mcp`) to attempt execution.[cite: 16]
**Correction:** We decoupled execution from the LLM. We built `analyze.sh` to deterministically extract the evidence first via `run_scan.py`, then hand the read-only text to the agent. This entirely eliminated execution hallucinations.[cite: 16]

### 2. False Positives: The Encryption Trap (VIGIA-REAL-005)
**Issue:** During baseline testing against VIGIA-REAL-005, the agent incorrectly flagged the case as `MALICIOUS` because it equated BitLocker and GPG keys with threat actor evasion.[cite: 16]
**Correction:** We applied strict forensic calibration to the agent's prompt. We engineered a rule dictating that encryption layers without explicit malware payloads must be classified as `SUSPICION`. The agent now successfully differentiates between legitimate privacy practices and hostile intent.[cite: 16]

### 3. Hallucinated Claims: Schema Drift via Model Upgrades
**Issue:** Upgrading to `gemini-3.1-flash-lite` for rate-limit and speed improvements caused the agent to hallucinate nested JSON keys, breaking the PDF reporting tool.[cite: 16]
**Correction:** We implemented a strict JSON schema template directly inside the bash prompt injection. The agent now flawlessly populates the required schema with zero formatting errors.[cite: 16]

### 4. Missed Artifacts & Known Limitations
While highly accurate at identifying anomalous process trees and documented IOCs, the agent currently relies on the depth of the initial Volatility extraction. If an artifact is deeply obfuscated in a registry hive not pulled by our initial script, the agent cannot currently request additional bespoke Volatility plugins to hunt it down, resulting in a missed artifact.[cite: 16]

### 5. Architectural Enforcement vs. Prompt Adherence (Addressing IDE Read-Only Limitations)
In accordance with Category 4 Hackathon requirements regarding Alternative Agentic IDEs (Aider), this section documents system behavior when the LLM attempts to violate read-only evidence constraints.[cite: 16]

Because Aider relies heavily on prompt adherence, a hallucinating model might attempt to rewrite the source evidence instead of the ledger. Our pipeline mitigates this through a dual-layer failure state:[cite: 16]
* **The Application Layer (Aider `--read` flag):** The orchestrator injects the source evidence (`telemetry_source.json` or `memory_scan_results.txt`) into Aider's context window explicitly as a read-only file. If the LLM generates a unified diff attempting to alter the evidence, Aider's core logic automatically rejects the edit block, preventing file modification.[cite: 16]
* **The OS Layer (Decoupled Extraction):** To ensure zero spoliation risk, `analyze.sh` entirely separates extraction from cognition. The AI never touches the original `.raw` or `.json` case files. It only receives a secondary, sanitized copy of the extraction.[cite: 16]
* **The Result:** If the model completely ignores the read-only prompt and attempts a destructive edit, the IDE rejects the diff, the Python validation loop catches the lack of updates to the `triage_ledger.json`, and the agent is forced into the self-correction REPL. Chain of custody for the underlying evidence remains mathematically unbroken.[cite: 16]
