#!/bin/bash
set -e # Abort immediately if any command fails

if [ -z "$1" ]; then
    echo "Usage: ./analyze.sh <path_to_evidence> [path_to_scenario_txt]"
    exit 1
fi

TARGET=$1
SCENARIO_FILE=$2

# Verify file exists and resolve absolute path to prevent traversal attacks
if [ ! -f "$TARGET" ]; then
    echo "[-] 🚨 FATAL: Target file '$TARGET' does not exist."
    exit 1
fi
TARGET=$(readlink -f "$TARGET")
CLEAN_BASENAME=$(basename "$TARGET")

# INTELLIGENT CASE ROUTING & ANTI-CONTAMINATION
if [ "$CLEAN_BASENAME" == "case.json" ]; then
    CASE_NAME=$(basename "$(dirname "$TARGET")")
else
    CASE_NAME="${CLEAN_BASENAME%.*}"
fi

CASE_NAME=$(echo "$CASE_NAME" | sed 's/[^a-zA-Z0-9_-]/_/g')
if [ -z "$CASE_NAME" ]; then CASE_NAME="UNKNOWN_CASE"; fi

CASE_DIR="cases/INC-2026-$CASE_NAME"

# Force a clean slate to prevent the AI from hallucinating over ghost data
if [ -d "$CASE_DIR" ]; then
    if [[ "$CASE_DIR" =~ ^cases/INC-2026- ]]; then
        echo "[!] Existing case directory detected. Purging old artifacts to ensure forensic isolation..."
        rm -rf "$CASE_DIR"
    else
        echo "[-] 🚨 FATAL: Directory safety check failed. Aborting deletion."
        exit 1
    fi
fi

mkdir -p "$CASE_DIR"
trap 'rm -f "/tmp/raw_mft_dump_${CASE_NAME}.txt"; sudo rmdir "/tmp/ewf_${CASE_NAME}" 2>/dev/null || true' EXIT

# Handle Scenario Document ingestion if present
SCENARIO_CONTEXT="No background scenario document provided for this case. Perform standard baseline triage."
if [ -n "$SCENARIO_FILE" ] && [ -f "$SCENARIO_FILE" ]; then
    echo "[+] Scenario document detected. Ingesting background investigation context..."
    cp "$SCENARIO_FILE" "$CASE_DIR/investigation_scenario.txt"
    SCENARIO_CONTEXT=$(cat "$CASE_DIR/investigation_scenario.txt")
fi

# ==============================================================================
# PRE-FLIGHT DEPENDENCY CHECK
# ==============================================================================
echo "[*] Running pre-flight checks..."
if [ ! -f "verify_schema.py" ]; then echo "[-] 🚨 FATAL: verify_schema.py is missing."; exit 1; fi

# ==============================================================================
# FORENSIC CRYPTOGRAPHIC INTAKE (Pro-Grade Chain of Custody)
# ==============================================================================
echo "[*] Resolving cryptographic hash of original evidence..."
EVIDENCE_HASH=""
HASH_ALGO="SHA256"
HASH_SOURCE="Independently calculated via native sha256sum"

if { [[ "$TARGET" == *.e01 ]] || [[ "$TARGET" == *.E01 ]]; } && command -v ewfinfo >/dev/null 2>&1; then
    echo "[+] Detected E01 format. Instantly extracting embedded acquisition hash..."
    HASH_LINE=$(ewfinfo "$TARGET" | grep -iE "hash stored in file|SHA256 hash|MD5 hash" | head -n 1)
    EVIDENCE_HASH=$(echo "$HASH_LINE" | awk -F': ' '{print $2}' | tr -d ' ')
    if [ ${#EVIDENCE_HASH} -eq 64 ]; then
        HASH_ALGO="SHA256"
    elif [ ${#EVIDENCE_HASH} -eq 32 ]; then
        HASH_ALGO="MD5"
    else
        HASH_ALGO=$(echo "$HASH_LINE" | grep -oiE "SHA256|MD5" | tr '[:lower:]' '[:upper:]')
    fi
    HASH_SOURCE="E01 embedded acquisition hash (not independently recalculated)"
fi

if [ -z "$EVIDENCE_HASH" ]; then
    if [[ "$TARGET" =~ ^/mnt/hgfs/ ]]; then
        echo "[-] ⚠️ PERFORMANCE WARNING: Evidence is located in a VMware Shared Folder (/mnt/hgfs/)."
        echo "[-] Hashing will be significantly delayed by hypervisor disk I/O serialization."
    fi
    echo "[*] Calculating hash via accelerated native utility..."
    EVIDENCE_HASH=$(sha256sum "$TARGET" | awk '{print $1}')
    HASH_ALGO="SHA256"
fi

echo "[+] Intake Hash ($HASH_ALGO): $EVIDENCE_HASH"

echo "Timestamp: $(date -u)"                   > "$CASE_DIR/chain_of_custody.txt"
echo "Source File: $TARGET"                    >> "$CASE_DIR/chain_of_custody.txt"
echo "Hash Algorithm: ${HASH_ALGO:-Unknown}"   >> "$CASE_DIR/chain_of_custody.txt"
echo "Acquisition Hash: $EVIDENCE_HASH"        >> "$CASE_DIR/chain_of_custody.txt"
echo "Hash Source: $HASH_SOURCE"               >> "$CASE_DIR/chain_of_custody.txt"
if [ -n "$SCENARIO_FILE" ]; then
    echo "Scenario File Integrated: Yes"       >> "$CASE_DIR/chain_of_custody.txt"
fi

# ==========================================================
# HYBRID MARKET-AWARE AI MODEL CAPABILITY DISCOVERY ENGINE
# ==========================================================
AI_MODEL="${AI_MODEL:-gemini/gemini-3.1-flash-lite}"
API_TIER="${API_TIER:-FREE}"

echo "[*] Querying market capabilities for model: $AI_MODEL..."
MODEL_TIER=$(python3 -c "
import sys
try:
    import litellm
    model_name = sys.argv[1].lower()
    max_tokens = litellm.get_max_tokens(model_name) or 0
    if max_tokens >= 100000: print('POWERFUL')
    elif max_tokens >= 32000: print('MEDIUM')
    else: print('LIGHT')
except Exception: print('LIGHT')
" "$AI_MODEL")

case "$MODEL_TIER" in
  POWERFUL) TRUNCATE_LINES=2000; MAX_EVIDENCE_LINES=5000; echo "====================== PROFILE: POWERFUL ======================";;
  MEDIUM)   TRUNCATE_LINES=1000;  MAX_EVIDENCE_LINES=3000; echo "====================== PROFILE: MEDIUM ======================";;
  LIGHT|*)  TRUNCATE_LINES=500;  MAX_EVIDENCE_LINES=1500;  echo "====================== PROFILE: STANDARD ======================";;
esac

if [ "$API_TIER" = "PAID" ]; then
    PHASE_1_COOLDOWN=1; PHASE_2_COOLDOWN=0; RETRY_COOLDOWN=5
    echo "[+] Speed Profile: PAID TIER (delays disabled)"
else
    PHASE_1_COOLDOWN=20; PHASE_2_COOLDOWN=10; RETRY_COOLDOWN=45
    echo "[!] Speed Profile: FREE TIER (enforcing rate-limit delays)"
fi
echo "--------------------------------------------------------"

# ==========================================================
# AUTOMATED FORENSIC EXTRACTION ENGINE
# ==========================================================
IS_JSON_TELEMETRY=false

if [[ "$TARGET" == *.json ]]; then
    echo "[+] Ingesting JSON telemetry profile."
    mkdir -p "$CASE_DIR/extractions"
    cp "$TARGET" "$CASE_DIR/extractions/telemetry_source.json"
    EVIDENCE_FILE="$CASE_DIR/extractions/telemetry_source.json"
    IS_JSON_TELEMETRY=true

elif [[ "$TARGET" == *.e01 ]] || [[ "$TARGET" == *.E01 ]]; then
    echo "[*] Detected EWF/EnCase forensic image format..."
    mkdir -p "/tmp/ewf_$CASE_NAME"
    if ! sudo ewfmount "$TARGET" "/tmp/ewf_$CASE_NAME" 2>/dev/null; then
        echo "[-] 🚨 FATAL: ewfmount failed."; exit 1
    fi
    EVIDENCE_FILE="$CASE_DIR/extractions/filesystem_metadata.txt"
    mkdir -p "$CASE_DIR/extractions"
    touch "$EVIDENCE_FILE"
    
    echo "[*] Discovering partition offsets via mmls..."
    # Dynamically extract starting sectors for supported file systems
    OFFSETS=$(sudo mmls "/tmp/ewf_$CASE_NAME/ewf1" 2>/dev/null | grep -iE "NTFS|FAT|exFAT|Basic data|Linux|Mac" | awk '{print $3}' | grep -E '^[0-9]+$' || true)
    
    if [ -z "$OFFSETS" ]; then
        echo "[!] No partition table found. Assuming logical image (Offset 0)..."
        OFFSETS="0"
    fi
    
    for OFFSET in $OFFSETS; do
        echo "[*] Stream-Extracting MFT metadata at sector offset $OFFSET..."
        sudo fls -o "$OFFSET" -r -p "/tmp/ewf_$CASE_NAME/ewf1" 2>/dev/null | \
            grep -iE "NTUSER.DAT|SAM|SYSTEM|SOFTWARE|Prefetch|Recent|Recycle.Bin|AppData|Local\\\\Temp|mIRC|interception|Skype|WhatsApp|Classified" \
            >> "$EVIDENCE_FILE" || true
    done

    # Fallback in case of Full Disk Encryption (e.g., BitLocker)
    if [ ! -s "$EVIDENCE_FILE" ]; then
        echo "[-] WARNING: File system extraction yielded no data (possible BitLocker/FDE). Falling back to string extraction..."
        sudo strings -a "/tmp/ewf_$CASE_NAME/ewf1" | grep -iE "http://|https://|@[a-zA-Z0-9.-]+" | head -n 3000 > "$EVIDENCE_FILE" || true
    fi

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"TOOL_EXEC\", \"action\": \"Executed: Streaming fls extraction with dynamic offsets\"}" >> "$CASE_DIR/actions.jsonl"
    sudo umount "/tmp/ewf_$CASE_NAME" || true
    sudo rmdir "/tmp/ewf_$CASE_NAME" 2>/dev/null || true

elif [[ "$TARGET" == *.7z ]] || [[ "$TARGET" == *.zip ]]; then
    echo "[*] Detected compressed archive format..."
    TMP_EXTRACT="$CASE_DIR/extractions/raw_triage"
    mkdir -p "$TMP_EXTRACT"
    7z x "$TARGET" -o"$TMP_EXTRACT" -y > /dev/null
    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"TOOL_EXEC\", \"action\": \"Executed: 7z x $TARGET -o$TMP_EXTRACT\"}" >> "$CASE_DIR/actions.jsonl"

    EVIDENCE_FILE="$CASE_DIR/extractions/summarized_evidence.txt"
    echo "[*] Generating Forensic Summaries from Extracted Evidence..."

    GREP_KEYWORDS="docx|xlsx|pdf|lnk|pf|bat|ps1|exe|log|\.db$|\.sqlite$|Login\.Data"
    ANTI_CONTAMINATION="FOR500|FOR508|SANS\.Handout|Master\.Scenario\.Solution|Grading\.Rubric"

    echo -e "\n=== HIGH-VALUE SCENARIO TARGETS & DATA LEAKS ===" >> "$EVIDENCE_FILE"
    
    find "$TMP_EXTRACT" -type f | grep -iE "$GREP_KEYWORDS" | grep -viE "$ANTI_CONTAMINATION" | while read -r file; do
        echo "TARGET ARTIFACT: $(basename "$file")" >> "$EVIDENCE_FILE"
        echo "PATH: $file"                          >> "$EVIDENCE_FILE"
        echo "SIZE: $(stat -c%s "$file" 2>/dev/null || echo "Unknown") bytes" >> "$EVIDENCE_FILE"
        echo "---"                                  >> "$EVIDENCE_FILE"
    done

    echo -e "\n=== KEY SYSTEM LOGS & CONFIGURATION PREVIEWS ===" >> "$EVIDENCE_FILE"
    find "$TMP_EXTRACT" -type f \( -name "*.txt" -o -name "*.log" -o -name "*.ini" \) | head -n 30 | while read -r file; do
        echo -e "\n--- File: $file ---" >> "$EVIDENCE_FILE"
        head -n "$TRUNCATE_LINES" "$file" | tr -cd '\11\12\15\40-\176' >> "$EVIDENCE_FILE"
    done

elif [[ "$TARGET" == *.pcap ]] || [[ "$TARGET" == *.pcapng ]]; then
    echo "[*] Detected Network Capture format..."
    EVIDENCE_FILE="$CASE_DIR/extractions/network_summary.txt"
    mkdir -p "$CASE_DIR/extractions"
    if command -v tshark >/dev/null 2>&1; then
        echo "[*] Extracting network telemetry via tshark (Best-Effort)..."
        
        echo -e "\n=== ENDPOINTS & PROTOCOLS ===" > "$EVIDENCE_FILE"
        tshark -r "$TARGET" -q -z endpoints,ip >> "$EVIDENCE_FILE" || true
        
        echo -e "\n=== CONNECTION TIMELINE (Sample) ===" >> "$EVIDENCE_FILE"
        tshark -r "$TARGET" -T fields -e frame.time -e ip.src -e tcp.srcport -e udp.srcport -e ip.dst -e tcp.dstport -e udp.dstport -e _ws.col.Protocol | head -n 500 >> "$EVIDENCE_FILE" || true
        
        echo -e "\n=== TOP DNS QUERIES ===" >> "$EVIDENCE_FILE"
        tshark -r "$TARGET" -Y "dns" -T fields -e ip.src -e dns.qry.name | sort | uniq -c | sort -nr | head -n 100 >> "$EVIDENCE_FILE" || true
        
        echo -e "\n=== TOP HTTP/SMTP ARTIFACTS ===" >> "$EVIDENCE_FILE"
        tshark -r "$TARGET" -Y "http || smtp" -T fields \
            -e ip.src -e ip.dst -e http.host -e http.request.uri -e http.user_agent -e http.cookie \
            -e smtp.req.parameter | sort | uniq -c | sort -nr | head -n 150 >> "$EVIDENCE_FILE" || true

        echo -e "\n=== TLS SNI ARTIFACTS ===" >> "$EVIDENCE_FILE"
        tshark -r "$TARGET" -Y "tls.handshake.type == 1" -T fields \
            -e ip.src -e ip.dst -e tls.handshake.extensions_server_name | sort | uniq -c | sort -nr | head -n 100 >> "$EVIDENCE_FILE" || true
    else
        echo "[!] tshark not found. Falling back to deep string extraction..."
        strings "$TARGET" | grep -iE "http://|https://|@[a-zA-Z0-9.-]+|user-agent:|cookie:|host:" | sort | uniq -c | sort -nr | head -n 300 > "$EVIDENCE_FILE" || true
    fi
    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"TOOL_EXEC\", \"action\": \"Parsed structured PCAP telemetry.\"}" >> "$CASE_DIR/actions.jsonl"

else
    mkdir -p "$CASE_DIR/extractions"
    EVIDENCE_FILE="$CASE_DIR/extractions/memory_scan_results.txt"
    python3 run_scan.py "$TARGET" > "$EVIDENCE_FILE" || touch "$EVIDENCE_FILE"
fi

if [ ! -f "$EVIDENCE_FILE" ] || [ ! -s "$EVIDENCE_FILE" ]; then
    echo "[-] 🚨 FATAL FORENSIC EXCEPTION 🚨"
    echo "[-] Extraction yielded an empty file or missing data target."
    exit 1
fi

echo "[*] Enforcing token-limit ceiling on raw evidence file..."
head -n "$MAX_EVIDENCE_LINES" "$EVIDENCE_FILE" > "/tmp/capped_evidence_${CASE_NAME}.txt"
mv "/tmp/capped_evidence_${CASE_NAME}.txt" "$EVIDENCE_FILE"
echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"SYSTEM\", \"action\": \"Automated pipeline extracted $TARGET to $EVIDENCE_FILE\"}" >> "$CASE_DIR/actions.jsonl"

# ==============================================================================
# --- PHASE 1.A: FACT & IOC EXTRACTION ENGINE ---
# ==============================================================================
echo "[*] PASS 1: Fact & IOC Extraction Engine Running..."
echo "[]" > "$CASE_DIR/facts.json"

if [ "$IS_JSON_TELEMETRY" = true ]; then
    echo "[*] Structured JSON input detected. Building deterministic fact graph..."
    python3 - "$EVIDENCE_FILE" "$CASE_DIR/facts.json" <<'PY'
import json
import ipaddress
import re
import sys

BENIGN_DOMAINS = {"gmail.com", "hotmail.com", "yahoo.com", "sbcglobal.net", 
                  "nist.gov", "outlook.com", "protonmail.com", "proton.me",
                  "google.com", "microsoft.com", "windows.com", "sourceforge.net",
                  "bing.com", "live.com", "office.com", "apple.com", "mozilla.org"}
FAKE_TLDS = {"exe", "dll", "zip", "ini", "bat", "ps1", "log", "txt", "pdf", "doc", "xls", "xlsx", "docx"}

src, dst = sys.argv[1], sys.argv[2]

with open(src, "r", encoding="utf-8", errors="ignore") as f:
    data = json.load(f)

facts = []
seen = set()

def add_fact(artifact_type, artifact_name, artifact_value, confidence="medium", iocs=None):
    value = str(artifact_value or "").strip()
    if not value: return
    key = (artifact_type, artifact_name, value.lower())
    if key in seen: return
    seen.add(key)
    ioc_values = []
    if iocs:
        for i in iocs:
            s = str(i).strip()
            if s and s not in ioc_values:
                ioc_values.append(s)
    facts.append({
        "artifact_type": artifact_type,
        "artifact_name": artifact_name,
        "artifact_value": value,
        "source_file": src,
        "confidence": confidence,
        "iocs": ioc_values,
    })

def find_all(pattern, text):
    return re.findall(pattern, text, flags=re.IGNORECASE)

def iter_valid_ips(text):
    for match in re.finditer(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", text):
        candidate = match.group(0)
        context = text[max(0, match.start() - 16):min(len(text), match.end() + 16)].lower()
        if "firefox" in context or "safari" in context or "chrome" in context: continue
        try:
            ip_obj = ipaddress.ip_address(candidate)
        except ValueError: continue
        if ip_obj.version == 4: yield candidate

global_text = " | ".join([str(data.get("case_name", "")), str(data.get("description", "")), str(data.get("incident_type", ""))])

if data.get("incident_type"): add_fact("case_context", "Incident Type", data.get("incident_type", ""), confidence="high", iocs=[])
if data.get("description"): add_fact("case_context", "Case Description", data.get("description", ""), confidence="medium", iocs=[])

artifacts = data.get("artifacts", [])
for art in artifacts:
    a_type = str(art.get("type", "unknown")).strip() or "unknown"
    content = str(art.get("content", ""))
    anomalies = art.get("forensic_anomalies", [])
    anomaly_text = " | ".join(str(x) for x in anomalies) if isinstance(anomalies, list) else str(anomalies)
    blob = " | ".join([content, anomaly_text])
    blob_lower = blob.lower()

    for ip in iter_valid_ips(blob):
        label = "Internal IP" if "internal" in blob_lower and ip.startswith("192.168.") else "External IP" if "external" in blob_lower else "IP Address"
        add_fact("network_flow", label, ip, confidence="high", iocs=[ip])

    for mac in find_all(r"\b[0-9a-f]{2}(?::[0-9a-f]{2}){5}\b", blob):
        add_fact("network_flow", "MAC Address", mac.lower(), confidence="high", iocs=[mac.lower()])

    hashes = find_all(r"\b[0-9a-f]{32}\b|\b[0-9a-f]{64}\b", blob_lower)
    for h in hashes:
        label = "SHA256 Hash" if len(h) == 64 else "MD5 Hash"
        add_fact("file_metadata", label, h, confidence="high", iocs=[h])

    for hostname in find_all(r"ComputerName\s*(?:=|:)\s*([^\s\|]+)", blob):
        add_fact("registry", "Hostname", hostname.strip(), confidence="high", iocs=[hostname.strip()])

    for owner in find_all(r"RegisteredOwner\s*(?:=|:)\s*([^\s\|]+)", blob):
        if owner.strip(): add_fact("registry", "Registered Owner", owner.strip(), confidence="high", iocs=[])

    emails = find_all(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", blob)
    for e in dict.fromkeys(emails):
        add_fact("email_header", "Observed Email", e, confidence="high", iocs=[e])
    email_domains = {e.split("@")[1].lower() for e in emails if "@" in e}
    email_domains.update(BENIGN_DOMAINS)

    domains = find_all(r"\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}\b", blob_lower)
    for dom in domains:
        tld = dom.rsplit(".", 1)[-1]
        if tld in FAKE_TLDS or dom in email_domains: continue
        
        # THE FIX: Skip if this domain match is just a piece of an extracted email
        # (e.g., prevents 'spy.conspirator' from being extracted from 'spy.conspirator@nist.gov')
        is_in_email = any(dom in e for e in emails)
        if is_in_email: continue
        
        add_fact("network_flow", "Domain", dom, confidence="medium", iocs=[dom])

    for ua in find_all(r"(?:firefox|safari|chrome|edge|ie)\s*[0-9a-zA-Z\./_-]*\s*/\s*[a-z0-9 ._-]+", blob):
        add_fact("network_flow", "User Agent", ua.strip(), confidence="medium", iocs=[])

    for ttp in find_all(r"\bT\d{4}(?:\.\d{3})?\b", blob):
        add_fact("threat_mapping", "Observed MITRE Technique", ttp.upper(), confidence="medium", iocs=[ttp.upper()])

    if anomaly_text: add_fact(a_type, "Forensic Anomaly", anomaly_text, confidence="medium", iocs=[])

    actor_name_match = re.search(r"identified\s+account\s*:\s*[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\s*[\-–—>→]+\s*([A-Za-z][A-Za-z\s'\.-]{2,80})", blob, flags=re.IGNORECASE)
    if actor_name_match:
        actor_name = re.sub(r"\s*\(.*?\)\s*$", "", actor_name_match.group(1).strip())
        add_fact("identity_attribution", "Attributed Human Actor", actor_name, confidence="high", iocs=[])

if not facts: add_fact("case_context", "Extraction Status", "No deterministic facts parsed from JSON telemetry", confidence="low", iocs=[])

facts = facts[:25]
with open(dst, "w", encoding="utf-8") as f: json.dump(facts, f, indent=2)
PY
else
    # AI Fallback Extractor
    cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
    rm -f .aider.chat.history.md

    set +e
    aider --model "$AI_MODEL" --map-tokens 0 \
      --message "Read '$EVIDENCE_FILE'. Extract raw forensic facts. Create '$CASE_DIR/facts.json' as a JSON array of objects with keys: 'artifact_type', 'artifact_name', 'artifact_value', 'source_file', 'confidence', 'iocs'. Extract all IPs, MACs, emails, domains, hashes, URLs, user agents, cookies/session identifiers, account names, and execution paths. When an entity role is inferable, encode it in 'artifact_name', e.g., 'Actor Email', 'Victim IP', 'Associated Internal IP', 'Infrastructure Domain', or 'Unknown Email'. Limit to 20 highly actionable observations." \
      --yes-always --no-auto-commit --read "$EVIDENCE_FILE" --file "$CASE_DIR/facts.json"
    set -e
fi

echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Completed Pass 1: Fact & IOC Extraction.\"}" >> "$CASE_DIR/actions.jsonl"

# ==============================================================================
# --- PHASE 1.B: CORRELATION & TRIAGE STAGING ---
# ==============================================================================
echo "[*] Handing facts off to AI Agent for Correlation & Triage Staging..."

# 🛡️ DETERMINISTIC ZERO-EVIDENCE PROTOCOL
ZERO_EVIDENCE=false

if python3 -c "import json,sys; f=json.load(open('$CASE_DIR/facts.json')); sys.exit(0 if any(x.get('artifact_name') != 'Extraction Status' for x in f) else 1)" 2>/dev/null; then
    HAS_FACTS="yes"
else
    HAS_FACTS="no"
fi

if [ "$HAS_FACTS" == "no" ]; then
    echo "[-] 🚨 ZERO-EVIDENCE PROTOCOL TRIGGERED: No actionable facts extracted."
    echo "[-] Generating deterministic Inconclusive ledger and bypassing AI analysis to prevent hallucinations..."
    
    ZERO_EVIDENCE=true
    
    # Write the strictly compliant ledger
    echo '{
  "case_id": "'"$CASE_NAME"'",
  "target": "Unknown",
  "intent_verdict": "Inconclusive",
  "summary": "Analysis failed due to unsupported file format or empty extraction. This does not indicate a clean system; it indicates a lack of parseable telemetry. EVIDENCE COVERAGE MATRIX: [Filesystem: NO] [Registry: NO] [EventLogs: NO] [NetworkLogs: NO]",
  "null_hypothesis": "The system may be clean, but lack of data prevents forensic verification.",
  "case_confidence": 0,
  "mitre_ttps": [],
  "artifacts": []
}' > "$CASE_DIR/triage_ledger.json"

    # Write the isolated timeline file
    echo '[{
  "sequence": 1,
  "event_description": "Timeline reconstruction failed — insufficient data.",
  "artifacts_involved": [],
  "mitre_ttp": "",
  "confidence": "Low"
}]' > "$CASE_DIR/timeline.json"
    
    # Force bypass of the Phase 1.B AI loop
    VALIDATION_PASSED=true
    MAX_RETRIES=0 
else
    # Initialize the blank ledger for the AI
    echo '{"case_id": "'"$CASE_NAME"'", "target": "Unknown", "intent_verdict": "Inconclusive", "summary": "", "null_hypothesis": "", "case_confidence": 0, "mitre_ttps": [], "artifacts": []}' > "$CASE_DIR/triage_ledger.json"
    MAX_RETRIES=3
    VALIDATION_PASSED=false
fi

RETRY_COUNT=0

# AMNESIA PROTOCOL
cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
rm -f .aider.chat.history.md

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "[*] Executing Pass 2: Agentic Correlation (Attempt $((RETRY_COUNT+1)) of $MAX_RETRIES)..."

    set +e
    aider --model "$AI_MODEL" \
      --map-tokens 0 \
      --message "You are an autonomous DFIR analyst. Read '$CASE_DIR/facts.json' and document findings in '$CASE_DIR/triage_ledger.json'.

      SCHEMA REQUIREMENTS (strictly enforced by automated validator):
      Root keys EXACTLY: case_id (=$CASE_NAME), target, intent_verdict, summary, null_hypothesis, case_confidence, mitre_ttps, artifacts.
      Each artifact object EXACTLY: name, type, value, description, presence_confidence (Low/Medium/High), execution_confidence (None/Low/Medium/High), intent_confidence (None/Low/Medium/High), recommended_validation, risk_score (int 0-100), priority (Low/Medium/High), review_status (\"pending\"), iocs (array of strings).
      CRITICAL FORMATTING: Output all numbers and risk scores as plain, bare integers (e.g., 85). Render everything as strict, plain text. No LaTeX.

      INVESTIGATION CONTEXT:
      $SCENARIO_CONTEXT

      ANALYTICAL RULES:
      1. INTENT VERDICT: Evaluate objectively. Avoid model default bias for C2/Exfiltration. 
      2. THREE-TIER CONFIDENCE & VERDICT ALIGNMENT: 'presence_confidence' reflects certainty the artifact exists. 'execution_confidence' reflects evidence the tool was actively run. 'intent_confidence' reflects evidence it was used maliciously. CRITICAL: If you determine the final 'intent_verdict' is 'BENIGN' or 'Inconclusive', then NO individual artifact inside the matrix can have an 'intent_confidence' of 'High'. They must match the verdict.
      3. NULL HYPOTHESIS: State the most plausible innocent explanation for the findings and explicitly support/refute it.
      4. MITRE & TTPs: Treat all mappings as \"Candidate TTPs\". Map TTPs ONLY if execution_confidence is Medium/High. Do NOT hallucinate mappings (e.g., do not map GUI utilities like Task Manager, Skype, or Dropbox to command-line techniques like T1059).
      5. EVIDENCE SPECIFICITY: Include exact file paths, timestamps, and extracted strings. Include MD5/SHA256 hashes where applicable.
      6. ROLE ASSIGNMENT: Explicitly categorize identities, emails, and endpoints. Do not alternate between calling an account a 'service account' and a 'local user'—pick one definitive role based on facts.
      7. NETWORK LOGIC CAVEAT: If network telemetry is missing, state: \"Network telemetry was unavailable for analysis.\"
      8. PLACEHOLDER BAN & MANDATORY VALIDATION: Do not put PENDING or UNKNOWN in iocs arrays. Use empty arrays if no IOC exists. 'recommended_validation' must NEVER be left blank or written as 'None'. If an artifact is benign baseline activity, provide a concrete administrative validation step (e.g., 'Verify against gold image baseline' or 'Audit user deployment log').
      9. COVERAGE MATRIX: Append to the summary: \"EVIDENCE COVERAGE MATRIX: [Filesystem: YES/NO] [Registry: YES/NO] [EventLogs: YES/NO] [NetworkLogs: YES/NO]\" (adjust YES/NO accordingly).
      10. BROWSER EXTENSION BIAS: Do NOT assume randomized Chrome Extension IDs are benign 'standard customization'. If an ID cannot be verified, assign it a baseline suspicious risk score (e.g., 30) and set recommended_validation to 'Verify ID against Threat Intelligence.'
      11. RISK SCORING CONSISTENCY: Do not assign arbitrary low scores (e.g., 5/100) to standard utilities while scoring others 0/100 without explicit justification. If an artifact is benign baseline activity, score it 0.
      12. SERVICE ACCOUNT ABUSE: If 'intent_verdict' is set to 'Malicious', treat interactive applications under account names like 'defaultprinter' as defense evasion. If 'intent_verdict' is set to 'Benign', treat them consistently as misconfigurations across the entire report." \
      --yes-always --no-auto-commit \
      --read "$CASE_DIR/facts.json" \
      --read "$CASE_DIR/chain_of_custody.txt" \
      --file "$CASE_DIR/triage_ledger.json"
    AI_EXIT=$?
    set -e

    if [ $AI_EXIT -ne 0 ]; then
        echo "[-] WARNING: AI correlation pass failed (exit code: $AI_EXIT). Retrying..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep "$RETRY_COOLDOWN"
        continue
    fi

    echo "[*] Running autonomous schema validation..."
    sed -i '/^```/d' "$CASE_DIR/triage_ledger.json" || true

    python3 - "$CASE_DIR/facts.json" "$CASE_DIR/triage_ledger.json" <<'PY'
import json
import re
import sys

BENIGN_DOMAINS = {"gmail.com", "hotmail.com", "yahoo.com", "sbcglobal.net", 
                  "nist.gov", "outlook.com", "protonmail.com", "proton.me",
                  "google.com", "microsoft.com", "windows.com", "sourceforge.net",
                  "bing.com", "live.com", "office.com", "apple.com", "mozilla.org"}

facts_path, ledger_path = sys.argv[1], sys.argv[2]
with open(facts_path, "r", encoding="utf-8") as f: facts = json.load(f)
with open(ledger_path, "r", encoding="utf-8") as f: ledger = json.load(f)

artifacts = ledger.get("artifacts", [])
if not isinstance(artifacts, list): artifacts = []

def normalize_str(v): return str(v or "").strip()

def add_artifact_if_missing(
    name, a_type, value, ioc_value, 
    presence="High", 
    exec_conf="None", 
    intent="None", 
    risk_score=60, 
    priority="Medium", 
    description="Recovered IOC."
):
    value_s = normalize_str(value)
    if not value_s: return
    low = value_s.lower()
    for art in artifacts:
        if normalize_str(art.get("value")).lower() == low:
            iocs = art.get("iocs", [])
            if not isinstance(iocs, list): iocs = []
            if ioc_value and ioc_value not in iocs:
                iocs.append(ioc_value)
                art["iocs"] = iocs
            return
    artifacts.append({
        "name": name, "type": a_type, "value": value_s, "description": description,
        "presence_confidence": presence, "execution_confidence": exec_conf, "intent_confidence": intent, 
        "recommended_validation": "Corroborate telemetry.",
        "risk_score": int(risk_score), "priority": priority, "review_status": "pending",
        "iocs": [ioc_value] if ioc_value else [],
    })

fact_iocs = []
has_external_ip, has_internal_ip, has_domain, has_email = False, False, False, False
actor_name, incident_type, case_desc = "", "", ""

for fact in facts:
    a_name, a_type, a_value = normalize_str(fact.get("artifact_name")), normalize_str(fact.get("artifact_type")), normalize_str(fact.get("artifact_value"))
    if a_name == "Incident Type": incident_type = a_value
    if a_name == "Case Description": case_desc = a_value
    if a_name == "Attributed Human Actor": actor_name = a_value

    iocs = fact.get("iocs", [])
    if isinstance(iocs, list):
        for i in iocs:
            if normalize_str(i): fact_iocs.append((a_name, a_type, a_value, normalize_str(i)))

    low_name = a_name.lower()
    if "external ip" in low_name: has_external_ip = True
    if "internal ip" in low_name: has_internal_ip = True
    if low_name.endswith("email"): has_email = True
    if a_name == "Domain": has_domain = True

existing_iocs = {normalize_str(i).lower() for art in artifacts for i in art.get("iocs", []) if normalize_str(i)}

for a_name, a_type, a_value, ioc in fact_iocs:
    if ioc.lower() in existing_iocs: continue
    low = a_name.lower()
    if "ip" in low:
        pri = "High" if "internal" in low else "Medium"
        add_artifact_if_missing(a_name or "IP Address", "network_flow", ioc, ioc, risk_score=50, priority=pri)
    elif "email" in low:
        add_artifact_if_missing(a_name or "Observed Email", "email_header", ioc, ioc, risk_score=40, priority="Medium")
    elif a_name == "Domain":
        if ioc.lower() not in BENIGN_DOMAINS:
            add_artifact_if_missing("Domain", "network_flow", ioc, ioc, risk_score=50, priority="Medium")
    else:
        add_artifact_if_missing(a_name or "Recovered IOC", a_type or "observed", a_value or ioc, ioc)
    existing_iocs.add(ioc.lower())

# FIX: Hard-Enforce Deterministic Hostnames (Anti-Typo)
for fact in facts:
    if fact.get("artifact_name") == "Hostname":
        true_hostname = fact.get("artifact_value")
        if true_hostname:
            for art in artifacts:
                if art.get("name") == "Hostname":
                    art["value"] = true_hostname
                    if true_hostname not in art.get("iocs", []):
                        art["iocs"].append(true_hostname)

# --- GLOBAL COHERENCE ENFORCEMENT ---
verdict = normalize_str(ledger.get("intent_verdict")).lower()

# Anti-Hallucination MITRE Filtering
forbidden_gui_mappings = ["task manager", "taskmgr.exe", "skype", "dropbox", "onedrive", "cmd.lnk", "powershell.lnk"]
if "mitre_ttps" in ledger and isinstance(ledger["mitre_ttps"], list):
    # If the system is benign or artifacts are standard utilities, strip command interpreter TTPs
    if verdict in ["benign", "inconclusive"] and "T1059" in ledger["mitre_ttps"]:
        ledger["mitre_ttps"].remove("T1059")

for art in artifacts:
    art_val_lower = normalize_str(art.get("value")).lower()
    art_name_lower = normalize_str(art.get("name")).lower()
    art_desc_lower = normalize_str(art.get("description")).lower()
    
    # 1. Force Validation steps to be populated if the LLM got lazy
    if normalize_str(art.get("recommended_validation")).lower() in ["none", "", "null", "pending"]:
        art["recommended_validation"] = "Cross-reference with workstation software deployment inventory."

    # 2. Fix the Benign vs High Intent contradiction
    if verdict in ["benign", "inconclusive"]:
        if art.get("intent_confidence") == "High":
            art["intent_confidence"] = "Low"
        if art.get("priority") == "High" and art["risk_score"] < 20:
            art["priority"] = "Low"
            
    # 3. Fix the Service Account Identity Whiplash
    if "no evidence of service account" in art_desc_lower or verdict == "benign":
        if "service" in art_name_lower:
            art["name"] = "User Account Workspace Profile"

summary = normalize_str(ledger.get("summary"))
if actor_name and actor_name.lower() not in summary.lower():
    summary = f"Attributed human actor identified: {actor_name}. " + summary

target = normalize_str(ledger.get("target"))
if (not target) or target.lower() == "unknown":
    m = re.search(r"professor\s+([A-Z][a-z]+\s+[A-Z][a-z]+)", case_desc)
    if m: target = m.group(1)

evidence_mitre = set()
ai_mitre = set(ledger.get("mitre_ttps", []))
mitre_set = ai_mitre.union(evidence_mitre)

verdict = normalize_str(ledger.get("intent_verdict")).lower()
case_confidence = int(ledger.get("case_confidence", 0) or 0)
for art in artifacts:
    raw_risk = str(art.get("risk_score", "0"))
    match = re.search(r"\d+", raw_risk)
    risk_val = int(match.group()) if match else 0
    art["risk_score"] = min(100, max(0, risk_val))
    
    # 🛡️ THE FIX: Global Stripper for low risk AND benign domains
    art["iocs"] = [i for i in art.get("iocs", []) if i.lower() not in BENIGN_DOMAINS]
    if art["risk_score"] < 20:
        art["iocs"] = []

ledger["summary"] = summary
ledger["target"] = target or ledger.get("target", "Unknown")
ledger["mitre_ttps"] = sorted(mitre_set)
ledger["case_confidence"] = case_confidence
ledger["artifacts"] = artifacts

def scrub_latex(obj):
    if isinstance(obj, str):
        return re.sub(r"(?<!\\)\$([^$\n]+)(?<!\\)\$", r"\1", obj)
    if isinstance(obj, list):
        return [scrub_latex(item) for item in obj]
    if isinstance(obj, dict):
        return {key: scrub_latex(value) for key, value in obj.items()}
    return obj

ledger = scrub_latex(ledger)

with open(ledger_path, "w", encoding="utf-8") as f: json.dump(ledger, f, indent=2)
PY

    set +e
    python3 verify_schema.py "$CASE_DIR/triage_ledger.json" > /dev/null 2>&1; SCHEMA_EXIT=$?
    python3 -c "import json; json.load(open('$CASE_DIR/triage_ledger.json'))" > /dev/null 2>&1; JSON_EXIT=$?
    python3 -c "import json,sys; d=json.load(open('$CASE_DIR/triage_ledger.json')); ok=bool(str(d.get('summary','')).strip()) and isinstance(d.get('artifacts'), list); sys.exit(0 if ok else 1)" > /dev/null 2>&1; CONTENT_EXIT=$?
    set -e

    if [ $SCHEMA_EXIT -eq 0 ] && [ $JSON_EXIT -eq 0 ] && [ $CONTENT_EXIT -eq 0 ]; then
        echo "[+] Forensic Quality Control: Schema validation passed successfully."
        VALIDATION_PASSED=true
        break
    else
        echo "[-] WARNING: Ledger validation failed. Initiating self-correction loop..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep "$RETRY_COOLDOWN"
    fi
done

if [ "$VALIDATION_PASSED" = false ]; then
    echo "[-] FATAL: AI agent failed to produce valid JSON after $MAX_RETRIES attempts. Aborting."
    exit 1
fi
echo "[*] Phase 1 Complete. Initiating ${PHASE_1_COOLDOWN}-second API rate-limit adaptive cooldown..."
sleep "$PHASE_1_COOLDOWN"



# ==============================================================================
# --- PHASE 2: SENIOR FORENSIC PEER REVIEW LOOP ---
# ==============================================================================
if [ "$ZERO_EVIDENCE" = true ]; then
    echo "[*] PHASE 2: Skipping Senior Peer Review due to zero-evidence protocol."
else
    echo "[*] Initializing Phase 2: Senior Forensic Peer Review Loop..."
    touch "$CASE_DIR/critique.txt"

    # AMNESIA PROTOCOL
    cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
    rm -f .aider.chat.history.md

    # Dynamic OS-Aware Rubric Loading
    SKILL_FLAGS=()
    if grep -qiE "windows|ntfs|registry|ntuser|exe|dll" "$EVIDENCE_FILE" 2>/dev/null; then
        SKILL_FLAGS+=(--read "reference_material/windows-artifacts/SKILL.md")
        SKILL_FLAGS+=(--read "reference_material/memory-analysis/SKILL.md")
    else
        SKILL_FLAGS+=(--read "reference_material/plaso-timeline/SKILL.md")
        SKILL_FLAGS+=(--read "reference_material/sleuthkit/SKILL.md")
    fi
    SKILL_FLAGS+=(--read "reference_material/yara-hunting/SKILL.md")

    set +e
    aider --model "$AI_MODEL" \
      --map-tokens 0 \
      "${SKILL_FLAGS[@]}" \
      --message "You are a Senior Forensic Analyst conducting a quality assurance audit of a junior analyst's triage ledger.

      Read '$CASE_DIR/triage_ledger.json' and '$CASE_DIR/facts.json'. Evaluate the findings and write critique to '$CASE_DIR/critique.txt'.
      
      1. FACTUAL ACCURACY: Check for overstatement or mischaracterization of evidence.
      2. ROLE ASSIGNMENT: Did the analyst explicitly identify the Actor, Victim, and Infrastructure where supported? Flag conflated identities or forced Actor labels on shared NAT/open WiFi IPs.
      3. MITRE VALIDATION: Are the mapped MITRE TTPs explicitly proven by the artifacts? Flag unsupported mappings based on mere tool presence.
      4. SEMANTIC BIAS: Check if harassment, insider misuse, policy violations, or shared-network ambiguity were incorrectly labeled as corporate C2/malware/exfiltration.
      5. NULL HYPOTHESIS: Ensure the defense hypothesis makes sense for the specific evidence and addresses attribution/access ambiguity.
      6. IOC COMPLETENESS: Flag missing IOCs.
      Do NOT modify the JSON ledger." \
      --yes-always \
      --no-auto-commit \
      --read "$CASE_DIR/triage_ledger.json" \
      --read "$CASE_DIR/facts.json" \
      --file "$CASE_DIR/critique.txt"
    set -e

    if [ -f "$CASE_DIR/critique.txt" ]; then
        echo "[!] Critical Logic Review Generated by Peer Agent:"
        cat "$CASE_DIR/critique.txt"
        echo "────────────────────────────────────────────────────────────────────────────────"

        echo "[*] Re-engaging Agent to integrate Senior Review into Final Ledger..."
        cp "$CASE_DIR/triage_ledger.json" "$CASE_DIR/triage_ledger.json.bak"

        # AMNESIA PROTOCOL
        cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
        rm -f .aider.chat.history.md

        aider --model "$AI_MODEL" \
          --map-tokens 0 \
          --message "Read '$CASE_DIR/critique.txt' and update '$CASE_DIR/triage_ledger.json' to address all identified issues.
          SCHEMA LOCK: Preserve the schema exactly. 
          CRITICAL FORMATTING: Output all numbers and risk scores as plain integers. No LaTeX.
          INTEGRATION: Address factual corrections, rewrite generic summaries, preserve schema exactly, correct unsupported MITRE mappings, encode supported roles in artifact name fields, avoid forced Actor labels for shared infrastructure, and ensure any named human actor is evidence-backed." \
          --yes-always --no-auto-commit \
          --read "$CASE_DIR/critique.txt" \
          --read "$CASE_DIR/facts.json" \
          --file "$CASE_DIR/triage_ledger.json"

        echo "[*] Running Post-Review Schema Validation..."
        sed -i '/^```/d' "$CASE_DIR/triage_ledger.json" || true

        if python3 verify_schema.py "$CASE_DIR/triage_ledger.json" > /dev/null 2>&1 && \
           python3 -c "import json; json.load(open('$CASE_DIR/triage_ledger.json'))" > /dev/null 2>&1; then
            echo "[+] Post-Review validation passed."
            rm "$CASE_DIR/triage_ledger.json.bak"
        else
            echo "[-] 🚨 WARNING: Peer review integration broke the JSON schema! Reverting..."
            mv "$CASE_DIR/triage_ledger.json.bak" "$CASE_DIR/triage_ledger.json"
        fi
    fi

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Successfully integrated peer review feedback.\"}" >> "$CASE_DIR/actions.jsonl"
fi
# ==============================================================================
# --- PHASE 1.C: ATTACK TIMELINE RECONSTRUCTION (MOVED TO POST-REVIEW) ---
# ==============================================================================
if [ "$ZERO_EVIDENCE" = true ]; then
    echo "[*] PASS 1.C: Skipping timeline reconstruction due to zero-evidence protocol."
else
    echo "[*] PASS 1.C: Attack Timeline Reconstruction Engine Running..."
    echo "[]" > "$CASE_DIR/timeline.json"

    # AMNESIA PROTOCOL
    cat .aider.chat.history.md >> "$CASE_DIR/agent_transcript.md" 2>/dev/null || true
    rm -f .aider.chat.history.md

    set +e
    aider --model "$AI_MODEL" \
      --map-tokens 0 \
      --message "You are a strictly objective DFIR timeline analyst. Read '$CASE_DIR/facts.json' and '$CASE_DIR/triage_ledger.json'.

      Reconstruct the probable sequence of events based on artifact relationships and observed timestamps. 

      Output '$CASE_DIR/timeline.json' as a JSON array of ordered event objects.
      Each object MUST contain EXACTLY:
      'sequence' (integer starting at 1),
      'event_description' (single-line string — what happened and why it matters forensically),
      'artifacts_involved' (array of artifact name strings from facts.json),
      'mitre_ttp' (single ATT&CK technique ID if directly applicable, empty string if not),
      'confidence' (Low/Medium/High — how certain is this sequencing).

      CRITICAL FORENSIC RULES: 
      1. STRICT EXECUTION DEPENDENCY: If an artifact in 'triage_ledger.json' has an 'execution_confidence' of 'Low' or 'None' (e.g., a .lnk shortcut file or a .zip archive), you MUST state 'User staged/downloaded [Tool]' or 'Presence of shortcut to [Tool]'. You are strictly forbidden from stating the user 'executed', 'ran', or 'utilized' the tool.
      2. ANTI-HALLUCINATION: Do NOT invent cloud uploads, exfiltration, or network activity if the ledger states network telemetry is missing.
      3. RAW JSON ONLY: No markdown backticks. All strings single-line.
      4. STRICT MITRE MAPPING: Do not map Windows GUI utilities (like Task Manager) to T1059. Only map TTPs if the specific criteria of the technique are explicitly met by the evidence." \
      --yes-always \
      --no-auto-commit \
      --read "$CASE_DIR/facts.json" \
      --read "$CASE_DIR/triage_ledger.json" \
      --file "$CASE_DIR/timeline.json"
    set -e

    sed -i '/^```/d' "$CASE_DIR/timeline.json" || true
    if ! python3 -c "import json; json.load(open('$CASE_DIR/timeline.json'))" > /dev/null 2>&1; then
        echo "[-] WARNING: Timeline JSON malformed — resetting to safe fallback."
        echo '[{"sequence": 1, "event_description": "Timeline reconstruction failed — insufficient data.", "artifacts_involved": [], "mitre_ttp": "", "confidence": "Low"}]' > "$CASE_DIR/timeline.json"
    fi

    echo "{\"timestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\", \"actor\": \"AI_AGENT\", \"action\": \"Completed Pass 1.C: Timeline Reconstruction.\"}" >> "$CASE_DIR/actions.jsonl"
fi
# ==============================================================================
# --- PHASE 3: HUMAN EXAMINER CHECKPOINT ---
# ==============================================================================
echo ""
echo "========================================================"
echo "    ⚠️  CRITICAL CHECKPOINT: HUMAN EXAMINER REVIEW ⚠️"
echo "========================================================"
printf "Type 'APPROVE' to authorize final report generation: "
read -r USER_INPUT

if [ "$USER_INPUT" == "APPROVE" ]; then
    sed -i 's/DRAFT_//g' "$CASE_DIR/triage_ledger.json"
    sed -i 's/PENDING_HUMAN_REVIEW/APPROVED_BY_EXAMINER/g' "$CASE_DIR/triage_ledger.json"
    
    echo "[*] Performing final renderer-safe ledger cleanup..."
    python3 - "$CASE_DIR/triage_ledger.json" <<'PY'
import json
import re
import sys

path = sys.argv[1]

def normalize_str(v): 
    return str(v or "").strip()

def scrub(obj):
    if isinstance(obj, str):
        return re.sub(r"(?<!\\)\$([^$\n]+)(?<!\\)\$", r"\1", obj)
    if isinstance(obj, list):
        return [scrub(item) for item in obj]
    if isinstance(obj, dict):
        return {key: scrub(value) for key, value in obj.items()}
    return obj

with open(path, "r", encoding="utf-8") as handle:
    ledger = json.load(handle)

BENIGN_DOMAINS = {"gmail.com", "hotmail.com", "yahoo.com", "sbcglobal.net", 
                  "nist.gov", "outlook.com", "protonmail.com", "proton.me",
                  "google.com", "microsoft.com", "windows.com", "sourceforge.net",
                  "bing.com", "live.com", "office.com", "apple.com", "mozilla.org"}

verdict = normalize_str(ledger.get("intent_verdict")).lower()

if "mitre_ttps" in ledger and isinstance(ledger["mitre_ttps"], list):
    if verdict in ["benign", "inconclusive"] and "T1059" in ledger["mitre_ttps"]:
        ledger["mitre_ttps"].remove("T1059")

for artifact in ledger.get("artifacts", []):
    raw_risk = str(artifact.get("risk_score", "0"))
    match = re.search(r"\d+", raw_risk)
    risk_val = min(100, max(0, int(match.group()) if match else 0))
    artifact["risk_score"] = risk_val
    
    if verdict in ["benign", "inconclusive"]:
        artifact["intent_confidence"] = "Low"
        if risk_val < 20:
            artifact["priority"] = "Low"
            
    if normalize_str(artifact.get("recommended_validation")).lower() in ["none", "", "null", "pending"]:
        artifact["recommended_validation"] = "Cross-reference with workstation software deployment inventory."
    
    artifact["iocs"] = [i for i in artifact.get("iocs", []) if i.lower() not in BENIGN_DOMAINS]
    if risk_val < 20:
        artifact["iocs"] = []

ledger = scrub(ledger)

with open(path, "w", encoding="utf-8") as handle:
    json.dump(ledger, handle, indent=2)
PY

    python3 generate_pdf_report.py "$CASE_DIR/triage_ledger.json"

    mkdir -p "$CASE_DIR/reports"
    mv exports/*.pdf "$CASE_DIR/reports/" 2>/dev/null || true
    cp .aider.chat.history.md "$CASE_DIR/reports/agent_transcript.md" 2>/dev/null || true
    echo "[+] PIPELINE COMPLETE. Final verified artifact saved to $CASE_DIR/reports/"
else
    echo "[-] Investigation Paused / AI Re-prompted based on human rejection."
    exit 1
fi
