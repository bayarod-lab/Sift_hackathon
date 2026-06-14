#!/usr/bin/env python3
"""
DFIR Executive PDF Report Generator (Dynamic Version)
Uses WeasyPrint to render styled HTML → PDF.
Accepts a JSON file as an argument to dynamically build reports for any case.
"""

import sys
import json
import re
import html
from pathlib import Path
from datetime import datetime, timezone

try:
    from weasyprint import HTML, CSS
except ImportError:
    raise SystemExit("weasyprint not installed. Run: pip3 install weasyprint")


# ── Brand / Style ─────────────────────────────────────────────────────────────

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
        content: "CONFIDENTIAL — DFIR INTERNAL USE ONLY";
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

/* ── Cover / Header ── */
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

.cover-top { }

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
    font-size: 28pt;
    font-weight: 700;
    line-height: 1.15;
    color: #ffffff;
    margin-bottom: 0.4cm;
}

.cover-subtitle {
    font-size: 13pt;
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
    width: 3cm;
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
.cover-date {
    font-size: 8pt;
    color: #93c5fd;
}

/* ── Page header stripe ── */
.page-header {
    background: #0f172a;
    color: white;
    padding: 0.35cm 2.2cm;
    display: flex;
    justify-content: space-between;
    align-items: center;
}
.page-header-title {
    font-size: 8.5pt;
    font-weight: 600;
    letter-spacing: 0.05em;
    color: #93c5fd;
}
.page-header-case {
    font-size: 8pt;
    color: #6b7280;
}

/* ── Content area ── */
.content {
    padding: 0.8cm 2.2cm 1.5cm 2.2cm;
}

/* ── Section headings ── */
h2 {
    font-size: 14pt;
    font-weight: 700;
    color: #0f172a;
    margin-top: 0.8cm;
    margin-bottom: 0.3cm;
    padding-bottom: 0.15cm;
    border-bottom: 2.5px solid #1d4ed8;
    display: flex;
    align-items: center;
    gap: 0.3cm;
}
h2 .section-num {
    background: #1d4ed8;
    color: white;
    font-size: 9pt;
    font-weight: 700;
    padding: 0.05cm 0.22cm;
    border-radius: 3px;
    min-width: 0.7cm;
    text-align: center;
}

/* ── Executive Summary box ── */
.exec-summary {
    background: #eff6ff;
    border-left: 4px solid #1d4ed8;
    border-radius: 0 6px 6px 0;
    padding: 0.4cm 0.6cm;
    margin: 0.3cm 0 0.5cm 0;
}
.exec-summary p { margin-bottom: 0.15cm; font-size: 9.5pt; }

.coverage-box {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    padding: 10px;
    margin-top: 10px;
    margin-bottom: 5px;
    border-radius: 4px;
}
.cov-title {
    font-size: 8.5pt;
    font-weight: 700;
    color: #334155;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 5px;
    display: block;
}
.cov-badge {
    display: inline-block;
    margin-right: 8px;
    margin-top: 4px;
    padding: 3px 6px;
    border-radius: 3px;
    font-size: 7.5pt;
    border: 1px solid #ccc;
}
.cov-yes { background: #dcfce7; color: #166534; border-color: #86efac; }
.cov-no { background: #fee2e2; color: #991b1b; border-color: #fca5a5; }

/* ── Meta Table (System Scope Only) ── */
table {
    width: 100%;
    border-collapse: collapse;
    margin: 0.25cm 0 0.5cm 0;
    font-size: 8.5pt;
    table-layout: fixed;
}
thead tr { background: #1e3a5f; color: white; }
thead th {
    padding: 0.18cm 0.28cm;
    text-align: left;
    font-weight: 600;
    font-size: 8pt;
    letter-spacing: 0.04em;
    text-transform: uppercase;
}
tbody tr { page-break-inside: avoid !important; }
tbody tr:nth-child(even) { background: #f8fafc; }
tbody tr:nth-child(odd)  { background: #ffffff; }
tbody td {
    padding: 0.15cm 0.28cm;
    border-bottom: 1px solid #e5e7eb;
    vertical-align: top;
    word-wrap: break-word;
}

/* ── Badges & Tags ── */
code {
    font-family: 'Roboto Mono', 'Courier New', monospace;
    font-size: 8pt;
    background: #f1f5f9;
    padding: 0.02cm 0.1cm;
    border-radius: 3px;
    color: #0f172a;
    word-break: break-all;
}

.risk-badge { display: inline-block; padding: 2px 6px; border-radius: 3px; font-size: 7.5pt; font-weight: bold; }
.risk-high { background: #fef2f2; color: #b91c1c; border: 1px solid #f87171; }
.risk-medium { background: #fffbeb; color: #b45309; border: 1px solid #fbbf24; }
.risk-low { background: #f8fafc; color: #334155; border: 1px solid #cbd5e1; }

.pri-badge { display: inline-block; padding: 2px 6px; border-radius: 3px; font-size: 7.5pt; font-weight: bold; text-transform: uppercase; }
.pri-high { background: #dc2626; color: white; }
.pri-medium { background: #f59e0b; color: white; }
.pri-low { background: #64748b; color: white; }

/* ── Artifact Cards (Replaces Table) ── */
.artifact-card {
    border: 1px solid #e2e8f0;
    background-color: #f8fafc;
    margin-bottom: 0.5cm;
    padding: 0.4cm;
    border-radius: 6px;
    page-break-inside: avoid;
}
.artifact-header {
    font-size: 10pt;
    font-weight: 700;
    border-bottom: 2px solid #cbd5e1;
    padding-bottom: 0.15cm;
    margin-bottom: 0.2cm;
    display: flex;
    justify-content: space-between;
    align-items: center;
}
.artifact-body {
    font-size: 9pt;
    line-height: 1.5;
    word-wrap: break-word;
    overflow-wrap: break-word;
}
.artifact-detail {
    margin-bottom: 0.15cm;
}
.artifact-detail-label {
    font-weight: 600;
    color: #475569;
}
.badges-container {
    margin-top: 0.2cm;
    display: flex;
    flex-wrap: wrap;
    gap: 5px;
}
.conf-badge {
    display: inline-block;
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 7.5pt;
    font-weight: 600;
    text-transform: uppercase;
    background: #e2e8f0;
    color: #334155;
    border: 1px solid #cbd5e1;
}
.conf-badge.high { background: #fee2e2; color: #991b1b; border-color: #fca5a5; }
.conf-badge.medium { background: #ffedd5; color: #9a3412; border-color: #fdba74; }
.conf-badge.low { background: #f1f5f9; color: #475569; border-color: #cbd5e1; }
.conf-badge.none { background: #f3f4f6; color: #9ca3af; border-color: #e5e7eb; }

/* ── Metric cards ── */
.metric-row { display: flex; gap: 0.3cm; margin: 0.3cm 0; }
.metric-card {
    flex: 1;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-top: 3px solid #1d4ed8;
    border-radius: 5px;
    padding: 0.3cm 0.4cm;
    text-align: center;
}
.metric-card.red-top  { border-top-color: #dc2626; }
.metric-card.orange-top { border-top-color: #f97316; }
.metric-card.green-top  { border-top-color: #16a34a; }
.metric-number { font-size: 16pt; font-weight: 700; color: #0f172a; line-height: 1.1; }
.metric-label { font-size: 7.5pt; font-weight: 600; color: #6b7280; text-transform: uppercase; letter-spacing: 0.07em; margin-top: 0.05cm; }

.footer-note {
    margin-top: 0.8cm;
    padding-top: 0.3cm;
    border-top: 1px solid #e5e7eb;
    font-size: 7.5pt;
    color: #9ca3af;
}
"""

def build_html(data: dict) -> str:
    case_id    = html.escape(data.get("case_id", "UNKNOWN-CASE"))
    client     = html.escape(data.get("client", "Automated Triage Pipeline"))
    prepared   = html.escape(data.get("prepared_by", "Autonomous DFIR Agent"))
    date_str   = html.escape(data.get("date", datetime.now().strftime("%Y-%m-%d")))
    title      = html.escape(data.get("title", "Dynamic Triage Assessment"))
    subtitle   = html.escape(data.get("subtitle", "Autonomous Forensic Report"))
    body_html  = data.get("body_html", "")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<style>{CSS_STYLE}</style>
</head>
<body>

<!-- ══ COVER PAGE ══ -->
<div class="cover">
  <div class="cover-top">
    <div class="org-tag">Digital Forensics &amp; Incident Response</div>
    <div class="report-type">Confidential Forensic Analysis</div>
    <h1>{title}</h1>
    <div class="cover-subtitle">{subtitle}</div>
    <div class="cover-divider"></div>
    <div class="cover-meta">
      <div class="cover-meta-row">
        <div class="cover-meta-label">Pipeline</div>
        <div class="cover-meta-value">{client}</div>
      </div>
      <div class="cover-meta-row">
        <div class="cover-meta-label">Case ID</div>
        <div class="cover-meta-value">{case_id}</div>
      </div>
      <div class="cover-meta-row">
        <div class="cover-meta-label">Prepared By</div>
        <div class="cover-meta-value">{prepared}</div>
      </div>
      <div class="cover-meta-row">
        <div class="cover-meta-label">Report Date</div>
        <div class="cover-meta-value">{date_str} UTC</div>
      </div>
    </div>
  </div>
  <div class="cover-bottom">
    <div class="cover-classification">&#9632; Confidential</div>
    <div class="cover-date">Report generated {date_str}</div>
  </div>
</div>

<!-- ══ BODY PAGES ══ -->
<div class="page-header">
  <div class="page-header-title">{title}</div>
  <div class="page-header-case">Case: {case_id}</div>
</div>
<div class="content">
{body_html}
<div class="footer-note">
  This report was produced automatically via an LLM-driven forensic pipeline.
  Findings are based strictly on evidence present in the provided target at the time of analysis.
</div>
</div>

</body>
</html>"""

def extract_coverage(summary_text: str) -> tuple:
    """Parses the 'Coverage: Filesystem: YES...' string out of the summary."""
    coverage_html = ""
    # Search for both old (=) and new (:) schema formats to be safe
    match = re.search(r'(EVIDENCE COVERAGE MATRIX:.*)(?:$|\n)', summary_text)
    if match:
        cov_str = match.group(1)
        summary_text = summary_text.replace(cov_str, '').strip()
        
        # Clean up the string to extract items
        clean_str = cov_str.replace("EVIDENCE COVERAGE MATRIX:", "").strip()
        
        # Support both [Filesystem: YES] and Filesystem=YES formats
        items = re.findall(r'\[?(Filesystem|Registry|EventLogs|NetworkLogs)[\:\=]\s*(YES|NO)\]?', clean_str)
        
        badges = ""
        for k, v in items:
            css_cls = "cov-yes" if v.upper() == "YES" else "cov-no"
            badges += f'<span class="cov-badge {css_cls}"><b>{html.escape(k)}</b>: {html.escape(v.upper())}</span>'
        
        if badges:
            coverage_html = f'<div class="coverage-box"><span class="cov-title">Evidence Coverage Matrix</span>{badges}</div>'
            
    return html.escape(summary_text), coverage_html

def build_dynamic_body(json_data: dict, real_target_path: str, case_dir: Path) -> str:
    verdict = html.escape(json_data.get("intent_verdict", "UNKNOWN").upper())
    raw_summary = json_data.get("summary", "No summary provided by the agent.")
    artifacts = json_data.get("artifacts", [])

    # Extract coverage matrix visually and escape the rest of the summary
    summary_safe, coverage_html = extract_coverage(raw_summary)

    # --- Extract MITRE TTPs ---
    mitre_ttps = json_data.get("mitre_ttps", [])
    mitre_html = ""
    if mitre_ttps:
        safe_ttps = [html.escape(ttp) for ttp in mitre_ttps]
        mitre_html = f'<div style="margin-top: 10px; margin-bottom: 15px; font-size: 8.5pt; color: #334155;"><b>Candidate MITRE ATT&CK Techniques:</b> <code>{", ".join(safe_ttps)}</code></div>'

    # --- Extract Null Hypothesis ---
    null_hypo = json_data.get("null_hypothesis", "")
    null_html = ""
    if null_hypo:
        null_html = f'<div style="background: #f1f5f9; border-left: 4px solid #64748b; padding: 10px; margin-top: 10px; margin-bottom: 15px; font-size: 8.5pt; border-radius: 0 4px 4px 0;"><b>Null Hypothesis Evaluation:</b> {html.escape(null_hypo)}</div>'

    # --- Extract Timeline ---
    timeline_html = ""
    timeline_path = case_dir / "timeline.json"
    if timeline_path.exists():
        try:
            with open(timeline_path, 'r', encoding='utf-8') as f:
                timeline_data = json.load(f)
            
            if timeline_data and isinstance(timeline_data, list):
                # Check if it's our zero-evidence fallback
                if len(timeline_data) == 1 and "failed" in timeline_data[0].get("event_description", "").lower():
                    pass # Skip rendering the timeline section if it's empty/failed
                else:
                    events = ""
                    for event in timeline_data:
                        seq = html.escape(str(event.get('sequence', '')))
                        desc = html.escape(str(event.get('event_description', '')))
                        ttp = html.escape(str(event.get('mitre_ttp', '')))
                        conf = html.escape(str(event.get('confidence', '')))
                        
                        ttp_badge = f'<span class="badge badge-high" style="margin-left: 8px;">{ttp}</span>' if ttp else ''
                        conf_tag = f'<span style="color:#9ca3af; font-size: 7.5pt; margin-left: 8px;">(Conf: {conf})</span>' if conf else ''
                        
                        events += f'<div style="margin-bottom: 10px; padding-left: 12px; border-left: 2px solid #cbd5e1; padding-bottom: 2px;"><b>Step {seq}:</b> {desc}{ttp_badge}{conf_tag}</div>'
                    
                    timeline_html = f'<h2><span class="section-num">02</span> Attack Sequence & Timeline</h2><div style="background: #f8fafc; padding: 15px; border-radius: 4px; font-size: 9pt; border: 1px solid #e2e8f0; margin-bottom: 15px;">{events}</div>'
        except Exception as e:
            print(f"[-] Warning: Failed to parse timeline.json for PDF rendering: {e}")

    # Set styles based on AI verdict
    verdict_color_class = "green-top"
    if verdict in ["MALICIOUS", "CONFIRMED MALICIOUS"]:
        verdict_color_class = "red-top"
    elif verdict == "SUSPICIOUS":
        verdict_color_class = "orange-top"

    # --- Build the Artifacts Cards dynamically ---
    artifacts_html = ""
    if len(artifacts) > 0:
        for art in artifacts:
            safe_name = html.escape(str(art.get("name", "Unknown Artifact")).strip())
            safe_val  = html.escape(str(art.get("value", "N/A")).strip())
            safe_desc = html.escape(str(art.get("description", "No description provided.")).strip())
            safe_rec  = html.escape(str(art.get("recommended_validation", "Manual review required.")).strip())

            # --- RENDER EXPLICIT IOC BLOCK ---
            iocs = art.get("iocs", [])
            if iocs and isinstance(iocs, list):
                valid_iocs = [html.escape(i.strip()) for i in iocs if i.strip()]
                if valid_iocs:
                    ioc_str = "<br>".join(valid_iocs)
                    safe_desc += f'<div style="margin-top: 8px; padding: 6px; background: #fee2e2; border-left: 3px solid #ef4444; border-radius: 3px; font-family: monospace; font-size: 7.5pt; word-wrap: break-word; color: #7f1d1d;"><b>INDICATORS OF COMPROMISE:</b><br>{ioc_str}</div>'

            # --- Extract Risk Score safely ---
            risk_raw = str(art.get("risk_score", "0")).replace("$", "").split("/")[0]
            risk_clean = re.sub(r'[^0-9]', '', risk_raw)
            risk_val = int(risk_clean) if risk_clean else 0
            safe_risk = html.escape(str(risk_val))
            
            raw_pri = str(art.get("priority", "Low")).strip().title()
            safe_pri = html.escape(raw_pri)

            risk_cls = "risk-low"
            if risk_val >= 75: risk_cls = "risk-high"
            elif risk_val >= 40: risk_cls = "risk-medium"
            
            pri_cls = "pri-low"
            if safe_pri == "High": pri_cls = "pri-high"
            elif safe_pri == "Medium": pri_cls = "pri-medium"

            header_right = f'<div style="display:flex; gap:5px;"><span class="risk-badge {risk_cls}">Risk: {safe_risk}/100</span><span class="pri-badge {pri_cls}">{safe_pri} Priority</span></div>'

            # --- Map the Three-Tier Confidence Values ---
            def get_conf_cls(val):
                v = val.upper()
                if "HIGH" in v: return "high"
                if "MEDIUM" in v: return "medium"
                if "LOW" in v: return "low"
                return "none"

            raw_pres = str(art.get("presence_confidence", "None")).strip()
            raw_exec = str(art.get("execution_confidence", "None")).strip()
            raw_int  = str(art.get("intent_confidence", "None")).strip()

            safe_pres = html.escape(raw_pres)
            safe_exec = html.escape(raw_exec)
            safe_int  = html.escape(raw_int)

            cls_pres = get_conf_cls(raw_pres)
            cls_exec = get_conf_cls(raw_exec)
            cls_int  = get_conf_cls(raw_int)

            artifacts_html += f"""
            <div class="artifact-card">
                <div class="artifact-header">
                    <span>{safe_name}</span>
                    {header_right}
                </div>
                <div class="artifact-body">
                    <div class="artifact-detail"><span class="artifact-detail-label">Value/Path:</span> <code>{safe_val}</code></div>
                    <div class="artifact-detail"><span class="artifact-detail-label">Observation:</span> {safe_desc}</div>
                    <div class="artifact-detail"><span class="artifact-detail-label">Validation:</span> {safe_rec}</div>
                    <div class="badges-container">
                        <span class="conf-badge {cls_pres}">Presence: {safe_pres}</span>
                        <span class="conf-badge {cls_exec}">Execution: {safe_exec}</span>
                        <span class="conf-badge {cls_int}">Intent: {safe_int}</span>
                    </div>
                </div>
            </div>
            """
    else:
        artifacts_html = "<p><em>No specific malicious or suspicious artifacts were extracted by the agent during this scan.</em></p>"

    # Dynamic Section Numbering based on Timeline Presence
    sys_sec = "03" if timeline_html else "02"
    matrix_sec = "04" if timeline_html else "03"

    html_content = f"""
    <h2><span class="section-num">01</span> Executive Summary</h2>
    <div class="exec-summary">
      <p>{summary_safe}</p>
    </div>
    {null_html}
    {coverage_html}
    {mitre_html}

    <div class="metric-row">
      <div class="metric-card {verdict_color_class}">
        <div class="metric-number">{verdict}</div>
        <div class="metric-label">Assessed Intent Verdict</div>
      </div>
      <div class="metric-card">
        <div class="metric-number">{len(artifacts)}</div>
        <div class="metric-label">Extracted Findings</div>
      </div>
    </div>
    
    {timeline_html}

    <h2><span class="section-num">{sys_sec}</span> System Profile &amp; Evidence Scope</h2>
    <table>
      <thead><tr><th style="width: 25%;">Property</th><th>Value</th></tr></thead>
      <tbody>
        <tr><td>Target Evidence Path</td><td><code>{html.escape(real_target_path)}</code></td></tr>
        <tr><td>Analysis Timestamp</td><td>{html.escape(datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"))}</td></tr>
        <tr><td>Analysis Tooling</td><td>Autonomous MCP Framework</td></tr>
      </tbody>
    </table>

    <h2><span class="section-num">{matrix_sec}</span> Extracted Findings Matrix</h2>
    {artifacts_html}
    """
    
    return html_content


def generate_report(data: dict, output_path: str, real_target_path: str) -> str:
    html_str = build_html(data)
    HTML(string=html_str).write_pdf(
        output_path,
        stylesheets=[CSS(string="")],
        presentational_hints=True,
    )
    return output_path


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Error: You must provide a JSON file.")
        print("Usage: python3 generate_pdf_report.py triage_report.json")
        sys.exit(1)

    json_filepath = sys.argv[1]

    try:
        with open(json_filepath, 'r') as f:
            triage_data = json.load(f)
    except Exception as e:
        print(f"Error reading JSON file {json_filepath}: {e}")
        sys.exit(1)

    # Pull the real target path from the chain_of_custody log to fix "Target: Unknown"
    case_dir = Path(json_filepath).parent
    coc_path = case_dir / "chain_of_custody.txt"
    real_target = triage_data.get("target", "Unknown")
    
    if coc_path.exists():
        try:
            for line in coc_path.read_text().splitlines():
                if line.startswith("Source File:"):
                    real_target = line.split("Source File:", 1)[1].strip()
                    break
        except Exception:
            pass

    current_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    case_id = triage_data.get("case_id", "UNKNOWN-CASE")
    
    report_data = {
        "case_id": case_id,
        "date": current_date,
        "title": "Dynamic Triage Assessment",
        "subtitle": "Autonomous Forensic Report",
        # FIX: Added the case_dir parameter here
        "body_html": build_dynamic_body(triage_data, real_target, case_dir),
    }

    exports_dir = Path("./exports/")
    exports_dir.mkdir(parents=True, exist_ok=True)
    output_pdf_path = exports_dir / f"Dynamic_Report_{case_id}.pdf"

    generate_report(report_data, str(output_pdf_path), real_target)
    print(f"[+] PDF incident report generated successfully: {output_pdf_path}")
