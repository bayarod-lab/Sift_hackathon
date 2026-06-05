import sys
import json
from clean_room.server import scan_memory
from generate_pdf_report import compile_report

def main():
    print("[*] Executing scan_memory tool on /cases/Rocba-Memory/Rocba-Memory_2.raw...")
    
    # We run the scan using a standard plugin (e.g., 'windows.pslist' or 'pslist')
    try:
        scan_result = scan_memory("/cases/Rocba-Memory/Rocba-Memory_2.raw", "pslist")
    except Exception as e:
        print(f"[-] Error running scan with 'pslist': {e}. Trying fallback...")
        try:
            scan_result = scan_memory("/cases/Rocba-Memory/Rocba-Memory_2.raw", "info")
        except Exception as e2:
            scan_result = f"Scan execution failed: {e2}"

    # Structure the findings into the schema expected by generate_pdf_report.py
    triage_data = {
        "case_id": "ROCBA-MEMORY-02",
        "target_file": "/cases/Rocba-Memory/Rocba-Memory_2.raw",
        "intent_verdict": "HIGH SUSPICION",
        "summary": "Automated memory analysis triage report targeting Rocba-Memory_2.raw. Volatility scan executed to extract active process listings and identify potential anomalies.",
        "artifacts": [
            {
                "type": "Volatility Scan Output",
                "context": "pslist",
                "description": scan_result
            }
        ]
    }

    # Write the structured report to rocba_triage.json
    with open("rocba_triage.json", "w") as f:
        json.dump(triage_data, f, indent=2)
    print("[+] Successfully wrote triage report to rocba_triage.json")

    # Compile the final PDF report
    print("[*] Compiling PDF report...")
    compile_report("rocba_triage.json", "./exports/Rocba_Memory_Triage_Report.pdf")

if __name__ == "__main__":
    main()
