import json
import sys

def verify_ledger(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"JSON Parse Error: {e}")
        sys.exit(1)

    # Define the strict expected schema
    root_keys = {'case_id', 'target', 'intent_verdict', 'summary', 'null_hypothesis', 'case_confidence', 'mitre_ttps', 'artifacts'}
    artifact_keys = {'name', 'type', 'value', 'description', 'presence_confidence', 'execution_confidence', 'intent_confidence', 'recommended_validation', 'risk_score', 'priority', 'review_status', 'iocs'}

    # Validate Root Level
    missing_root = root_keys - set(data.keys())
    if missing_root:
        print(f"Schema Error: Missing root keys: {missing_root}")
        sys.exit(1)

    # Validate Artifact Level
    for idx, art in enumerate(data.get('artifacts', [])):
        missing_art = artifact_keys - set(art.keys())
        if missing_art:
            print(f"Schema Error: Artifact {idx} missing keys: {missing_art}")
            sys.exit(1)

    # If we make it here, the schema is perfect
    sys.exit(0)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 verify_schema.py <path_to_ledger.json>")
        sys.exit(1)
    verify_ledger(sys.argv[1])
