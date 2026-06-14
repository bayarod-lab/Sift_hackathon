import json
import os
import sys

def eval_case(case_num):
    case_str = f"VIGIA-REAL-{case_num:03d}"
    ledger_path = f"cases/INC-2026-{case_str}/triage_ledger.json"
    truth_path = f"/mnt/hgfs/Vm shared folder/vigia-cases-main/vigia-cases-main/cases/{case_str}/ground_truth.json"
    
    if not os.path.exists(ledger_path):
        return f"{case_str} | MISSING_LEDGER"
    if not os.path.exists(truth_path):
        return f"{case_str} | MISSING_TRUTH"
        
    try:
        with open(ledger_path) as f:
            ledger = json.load(f)
        with open(truth_path) as f:
            truth = json.load(f)
    except Exception as e:
        return f"{case_str} | ERROR: {e}"
        
    # Verdict
    expected_verdict = truth.get('verdict', '').strip().upper()
    got_verdict = ledger.get('intent_verdict', '').strip().upper()
    if 'MALIC' in expected_verdict:
        verdict_ok = 'MALIC' in got_verdict
    elif 'BENIGN' in expected_verdict:
        verdict_ok = 'BENIGN' in got_verdict
    elif 'SUSP' in expected_verdict:
        verdict_ok = 'SUSP' in got_verdict
    else:
        verdict_ok = expected_verdict in got_verdict
        
    # IOCs
    ledger_iocs = set()
    for a in ledger.get('artifacts', []):
        for i in a.get('iocs', []):
            ledger_iocs.add(str(i).lower())
    truth_iocs = {i['value'].lower() for i in truth.get('key_iocs', [])}
    iocs_missed = truth_iocs - ledger_iocs
    iocs_ok = len(iocs_missed) == 0
    
    # MITRE
    ledger_ttps = {str(x).upper() for x in ledger.get('mitre_ttps', [])}
    truth_ttps = {str(x).upper() for x in truth.get('mitre_ttps', [])}
    mitre_missed = truth_ttps - ledger_ttps
    mitre_ok = len(mitre_missed) == 0
    
    # Confidence
    conf_ok = int(ledger.get('case_confidence', 0)) >= int(truth.get('confidence_threshold', 0))
    
    score = sum([verdict_ok, iocs_ok, mitre_ok, conf_ok])
    
    res = f"{case_str} | Score: {score}/4 | Verdict: {'PASS' if verdict_ok else 'FAIL'} | IOCs: {'PASS' if iocs_ok else 'FAIL'} | MITRE: {'PASS' if mitre_ok else 'FAIL'} | Conf: {'PASS' if conf_ok else 'FAIL'}"
    if not iocs_ok:
        res += f"\n    -> Missed IOCs: {iocs_missed}"
    if not mitre_ok:
        res += f"\n    -> Missed MITRE: {mitre_missed}"
        
    return res

print(f"{'='*80}\nBENCHMARK EVALUATION (VIGIA-REAL-001 to 010)\n{'='*80}")
total_score = 0
total_max = 0
for i in range(1, 11):
    result = eval_case(i)
    print(result)
    print("-" * 80)
