#!/usr/bin/env python3
"""
DFIR Universal Executive PDF Report Generator
Uses WeasyPrint to render styled HTML → PDF dynamically.
Can be imported as a module or run from the CLI passing a JSON file path.
"""

import sys
import json
import datetime
from pathlib import Path

try:
    from weasyprint import HTML, CSS
except ImportError:
    raise SystemExit("weasyprint not installed. Run: pip3 install weasyprint")

# ── Universal Brand & Layout Style ───────────────────────────────────────────
CSS_STYLE = """
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&family=Roboto+Mono:wght@400;600&display=swap');

@page {
    size: A4;
    margin: 0;
    @bottom-right {
        content: "Page " counter(page) " of " counter(pages);
        font-family: 'Inter', sans-serif;
        font-size: 8pt;
        color: #9ca3af;
        margin-right: 2cm;
        margin-bottom: 0.6cm;
    }
    @bottom-left {
        content: "CONFIDENTIAL — DFIR AUTOMATED ANALYSIS REPORT";
        font-family: 'Inter', sans-serif;
        font-size: 8pt;
        color: #9ca3af;
        margin-left: 2cm;
        margin-bottom: 0.6cm;
    }
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
    font-family: 'Inter', 'Helvetica Neue', Arial, sans-serif;
    font-size: 9.5pt;
    color: #1f2937;
    background: #ffffff;
    line-height: 1.55;
}

.cover {
    background: linear-gradient(135deg, #0f172a 0%, #1e3a5f 60%, #1d4ed8 100%);
    color: white;
    padding: 2.8cm 2.2cm 2cm 2.2cm;
    page-break-after: always;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
}

.org-tag {
    font-size: 8pt;
    font-weight: 600;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: #93c5fd;
    margin-bottom: 0.5cm;
}

.report-type {
    font-size: 10pt;
    font-weight: 400;
    color: #bfdbfe;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    margin-bottom: 0.3cm;
}

.cover h1 {
    font-size: 26pt;
    font-weight: 700;
    line-height: 1.15;
    color: #ffffff;
    margin-bottom: 0.4cm;
}

.cover-subtitle {
    font-size: 12pt;
    font-weight: 300;
    color: #bfdbfe;
    margin-bottom: 1cm;
}

.cover-divider {
    width: 60px;
    height: 4px;
    background: #3b82f6;
    border-radius: 2px;
    margin: 0.6cm 0 1cm 0;
}

.cover-meta {
    display: table;
    border-collapse: collapse;
    width: 100%;
    margin-top: 0.6cm;
}
.cover-meta-row { display: table-row; }
.cover-meta-label {
    display: table-cell;
    font-size: 8pt;
    font-weight: 600;
    color: #93c5fd;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    padding: 0.12cm 0.6cm 0.12cm 0;
    white-space: nowrap;
    width: 3.5cm;
}
.cover-meta-value {
    display: table-cell;
    font-size: 9pt;
    color: #e0f2fe;
    padding: 0.12cm 0;
}

.cover-bottom {
    border-top: 1px solid rgba(255,255,255,0.15);
    padding-top: 0.4cm;
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
}
.cover-classification {
    font-size: 8pt;
    font-weight: 700;
    letter-spacing: 0.15em;
    color: #fbbf24;
    text-transform: uppercase;
}
.cover-date { font-size: 8pt; color: #93c5fd; }

.page-header {
    background: #0f172a;
    color: white;
    padding: 0.35cm 2.2cm;
    display: flex;
    justify-content: space-between;
    align-items: center;
}
.page-header-title { font-size: 8.5pt; font-weight: 600; letter-spacing: 0.05em; color: #93c5fd; }
.page-header-case { font-size: 8pt; color: #9ca3af; }

.content { padding: 0.8cm 2.2cm 1.5cm 2.2cm; }

h2 {
    font-size: 13pt;
    font-weight: 700;
    color: #0f172a;
    margin-top: 0.8cm;
    margin-bottom: 0.3cm;
    padding-bottom: 0.15cm;
    border-bottom: 2.5px solid #1d4ed8;
}
h3 { font-size: 10.5pt; font-weight: 700; color: #1e3a5f; margin-top: 0.5cm; margin-bottom: 0.2cm; }
p { margin-bottom: 0.25cm; }

.exec-summary {
    background: #eff6ff;
    border-left: 4px solid #1d4ed8;
    border-radius: 0 6px 6px 0;
    padding: 0.4cm 0.6cm;
    margin: 0.3cm 0 0.5cm 0;
}
.exec-summary p { margin-bottom: 0.15cm; font-size: 9.5pt; }
.exec-summary p:last-child { margin-bottom: 0; }

.alert { border-radius: 5px; padding: 0.3cm 0.5cm; margin: 0.3cm 0; font-size: 9pt; border-left: 4px solid; }
.alert-MALICIOUS { background: #fef2f2; border-left-color: #dc2626; color: #1f2937; }
.alert-SUSPICION { background: #fff7ed; border-left-color: #f97316; color: #1f2937; }
.alert-BENIGN    { background: #f0fdf4; border-left-color: #16a34a; color: #1f2937; }
.alert-title { font-weight: 700; font-size: 9pt; margin-bottom: 0.1cm; text-transform: uppercase; }
.alert-MALICIOUS .alert-title { color: #dc2626; }
.alert-SUSPICION .alert-title { color: #c2410c; }
.alert-BENIGN .alert-title { color: #15803d; }

table { width: 100%; border-collapse: collapse; margin: 0.25cm 0 0.5cm 0; font-size: 8.8pt; }
thead tr { background: #1e3a5f; color: white; }
thead th { padding: 0.18cm 0.28cm; text-align: left; font-weight: 600; font-size: 8pt; letter-spacing: 0.04em; text-transform: uppercase; }
tbody tr:nth-child(even) { background: #f8fafc; }
tbody td { padding: 0.15cm 0.28cm; border-bottom: 1px solid #e5e7eb; vertical-align: top; }

code { font-family: 'Roboto Mono', monospace; font-size: 8pt; background: #f1f5f9; padding: 0.02cm 0.1cm; border-radius: 3px; color: #0f172a; }

.footer-note { margin-top: 0.8cm; padding-top: 0.3cm; border-top: 1px solid #e5e7eb; font-size: 7.5pt; color: #9ca3af; }
"""

def generate_dynamic_html(data: dict) -> str:
    """Transforms a completely generic data model into a clean HTML layout."""
    case_id     = data.get("case_id", "UNKNOWN-CASE")
    target_file = data.get("target_file", "Not Specified")
    verdict     = data.get("intent_verdict", "SUSPICION").upper()
    summary     = data.get("summary", "No automated summary provided.")
    date_str    = data.get("date", datetime.datetime.utcnow().strftime("%Y-%m-%d"))
    indicators  = data.get("indicators", [])

    # Map the metrics dynamic collection
    metrics = data.get("metrics", {
        "Threat Level": verdict,
        "Anomalies Found": str(len(indicators)),
        "Status": data.get("status", "COMPLETED")
    })

    # Generate metric columns dynamically
    metric_cards_html = ""
    for label, val in metrics.items():
        top_color_class = "red-top" if "mal" in val.lower() or "crit" in val.lower() else "orange-top" if "susp" in val.lower() else "green-top"
        metric_cards_html += f"""
        <div class="metric-card {top_color_class}" style="flex: 1; background: #f8fafc; border: 1px solid #e2e8f0; border-top: 3px solid #1d4ed8; border-radius: 5px; padding: 0.3cm 0.4cm; text-align: center; margin-right: 10px;">
            <div class="metric-number" style="font-size: 16pt; font-weight: 700; color: #0f172a;">{val}</div>
            <div class="metric-label" style="font-size: 7.5pt; font-weight: 600; color: #6b7280; text-transform: uppercase;">{label}</div>
        </div>"""

    # Generate dynamic table lines for indicators
    table_rows_html = ""
    if indicators:
        for ind in indicators:
            ind_type = ind.get("type", "Anomaly")
            desc = ind.get("description", "No detail specified")
            pid = ind.get("pid", "N/A")
            table_rows_html += f"<tr><td><strong>{ind_type}</strong></td><td><code>{pid}</code></td><td>{desc}</td></tr>"
    else:
        table_rows_html = "<tr><td colspan='3' style='text-align:center; color:#6b7280;'>No tactical anomalies explicit in evidence data matrix.</td></tr>"

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8"/>
<style>{CSS_STYLE}</style>
</head>
<body>

<div class="cover">
  <div class="cover-top">
    <div class="org-tag">Digital Forensics &amp; Incident Response</div>
    <div class="report-type">Automated Triage Deliverable</div>
    <h1>Incident Triage Analysis</h1>
    <div class="cover-subtitle">Target: {target_file}</div>
    <div class="cover-divider"></div>
    <div class="cover-meta">
      <div class="cover-meta-row"><div class="cover-meta-label">Case ID</div><div class="cover-meta-value">{case_id}</div></div>
      <div class="cover-meta-row"><div class="cover-meta-label">Target File</div><div class="cover-meta-value"><code>{target_file}</code></div></div>
      <div class="cover-meta-row"><div class="cover-meta-label">Intent Verdict</div><div class="cover-meta-value" style="font-weight:700;">{verdict}</div></div>
      <div class="cover-meta-row"><div class="cover-meta-label">Analysis Date</div><div class="cover-meta-value">{date_str} UTC</div></div>
    </div>
  </div>
  <div class="cover-bottom">
    <div class="cover-classification">&#9632; CONFIDENTIAL — AUTOMATED OUTPUT</div>
    <div class="cover-date">Generated {date_str}</div>
  </div>
</div>

<div class="page-header">
  <div class="page-header-title">Incident Triage Summary Report</div>
  <div class="page-header-case">Case: {case_id}</div>
</div>

<div class="content">
  <h2><span class="section-num">01</span> Executive Analysis Summary</h2>
  <div class="exec-summary">
    <p>{summary}</p>
  </div>

  <div style="display: flex; margin-bottom: 0.6cm;">
    {metric_cards_html}
  </div>

  <h2><span class="section-num">02</span> Automated Intent Valuation</h2>
  <div class="alert alert-{verdict}">
    <div class="alert-title">VERDICT STATUS: {verdict}</div>
    The host evidence profile exhibits telemetry matching the operational profile of {verdict}. Actions should prioritize the alignment steps indicated below.
  </div>

  <h2><span class="section-num">03</span> Tactical Indicators Observed</h2>
  <table>
    <thead><tr><th>Classification Type</th><th>Target Context/PID</th><th>Technical Artifact Details</th></tr></thead>
    <tbody>
        {table_rows_html}
    </tbody>
  </table>

  <div class="footer-note">
    This document was programmatically assembled by an automated DFIR Incident Response Pipeline.
    All underlying structural measurements trace securely to original evidence objects. Evidentiary integrity maintained via strict context bounds.
  </div>
</div>

</body>
</html>"""

def run_compilation(json_source_path: str, output_pdf_path: str = "./exports/Automated_Executive_Report.pdf"):
    source = Path(json_source_path)
    if not source.exists():
        print(f"Error: Target json path {json_source_path} not found.")
        return
        
    with open(source, "r") as f:
        case_data = json.load(f)
        
    # Standardize data structure defaults if it is evaluating straight from custom logs
    if "summary" not in case_data:
        case_data["summary"] = case_data.get("description", "No case abstract description provided within data file.")
        
    html_out = generate_dynamic_html(case_data)
    
    out_file = Path(output_pdf_path)
    out_file.parent.mkdir(parents=True, exist_ok=True)
    
    HTML(string=html_out).write_pdf(str(out_file))
    print(f"[+] Beautiful Dynamic Executive PDF Generated: {out_file.resolve()}")

if __name__ == "__main__":
    # If called straight from CLI, assume the data comes from your case logs
    default_json = "./vigia-intent-analysis/cases/VIGIA-REAL-005/case.json"
    if len(sys.argv) > 1:
        default_json = sys.argv[1]
    
    run_compilation(default_json)
