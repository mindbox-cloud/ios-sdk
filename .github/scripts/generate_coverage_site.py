#!/usr/bin/env python3
"""Builds a static coverage site (index.html + history.json + coverage.csv) from an .xcresult.

Usage: generate_coverage_site.py <path.xcresult> <output_dir> [previous_history.json]

Coverage comes from `xcrun xccov view --report --json`; *.xctest bundles are
excluded so the numbers reflect the shipped frameworks only. History is carried
forward by the caller: the workflow downloads the currently published
history.json from the live Pages site and passes it in; this script appends
today's point and ships the merged file with the new site, so the trend
survives even though every Pages deploy replaces the whole site.

The page is fully self-contained: inline CSS/JS, no external resources.
"""
import csv
import html
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

HISTORY_LIMIT = 1000


def pct(value):
    return f"{value * 100:.1f}%"


def bar(value):
    width = round(value * 100, 1)
    color = "#2da44e" if value >= 0.7 else "#d4a72c" if value >= 0.4 else "#cf222e"
    return (f'<div class="track"><div style="background:{color};width:{width}%;'
            f'height:10px;border-radius:3px"></div></div>')


def load_history(path):
    if not path or not os.path.exists(path):
        return []
    try:
        history = json.load(open(path))
        if not isinstance(history, list):
            return []
    except (json.JSONDecodeError, OSError):
        return []
    # Points written before the ts field existed carry only the human-readable
    # UTC string; synthesize ts from it so all dates render uniformly.
    for point in history:
        if "ts" not in point:
            try:
                parsed = datetime.strptime(point.get("date", ""), "%Y-%m-%d %H:%M UTC")
                point["ts"] = parsed.replace(tzinfo=timezone.utc).isoformat(timespec="seconds")
            except ValueError:
                pass
    return history


def repo_relative(path, repo):
    workspace = os.environ.get("GITHUB_WORKSPACE")
    if workspace and path.startswith(workspace + "/"):
        return path[len(workspace) + 1:]
    marker = f"/{repo.rsplit('/', 1)[-1]}/"
    idx = path.rfind(marker)
    return path[idx + len(marker):] if idx >= 0 else None


def trend_svg(history):
    points = [p["coverage"] for p in history][-90:]
    if len(points) < 2:
        return "<p>Trend appears after the second deploy.</p>"
    lo, hi = min(points), max(points)
    pad = max((hi - lo) * 0.15, 0.5)
    lo, hi = lo - pad, hi + pad
    w, h = 640, 120
    step = w / (len(points) - 1)
    coords = " ".join(f"{i * step:.1f},{h - (v - lo) / (hi - lo) * h:.1f}" for i, v in enumerate(points))
    return (f'<svg width="{w}" height="{h}" class="chart">'
            f'<polyline fill="none" stroke="#2da44e" stroke-width="2" points="{coords}"/></svg>'
            f'<p class="muted">last {len(points)} deploys, {points[0]:.1f}% &rarr; {points[-1]:.1f}%</p>')


def write_csv(path, targets, repo):
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["target", "file", "path", "executable_lines",
                         "covered_lines", "uncovered_lines", "line_coverage_percent"])
        for t in targets:
            for fl in t.get("files", []):
                writer.writerow([
                    t["name"], fl["name"],
                    repo_relative(fl.get("path", ""), repo) or fl.get("path", ""),
                    fl["executableLines"], fl["coveredLines"],
                    fl["executableLines"] - fl["coveredLines"],
                    round(fl["lineCoverage"] * 100, 2),
                ])


def main():
    xcresult, outdir = sys.argv[1], sys.argv[2]
    previous_history = sys.argv[3] if len(sys.argv) > 3 else None
    repo = os.environ.get("GITHUB_REPOSITORY", "mindbox-cloud/ios-sdk")
    branch = os.environ.get("GITHUB_REF_NAME", "local")
    sha = os.environ.get("GITHUB_SHA", "local")[:9]
    now = datetime.now(timezone.utc)
    date = now.strftime("%Y-%m-%d %H:%M UTC")
    iso = now.isoformat(timespec="seconds")

    report = json.loads(subprocess.run(
        ["xcrun", "xccov", "view", "--report", "--json", xcresult],
        check=True, capture_output=True).stdout)
    targets = [t for t in report["targets"] if not t["name"].endswith(".xctest")]
    executable = sum(t["executableLines"] for t in targets)
    covered = sum(t["coveredLines"] for t in targets)
    overall = covered / executable if executable else 0.0

    history = load_history(previous_history)
    if not history or history[-1].get("sha") != sha:
        history.append({
            "date": date,
            "ts": iso,
            "branch": branch,
            "sha": sha,
            "coverage": round(overall * 100, 2),
            "targets": {t["name"]: round(t["lineCoverage"] * 100, 2) for t in targets},
        })
    history = history[-HISTORY_LIMIT:]

    target_rows = "".join(
        f"<tr><td>{html.escape(t['name'])}</td><td>{pct(t['lineCoverage'])}</td>"
        f"<td>{bar(t['lineCoverage'])}</td><td>{t['coveredLines']}/{t['executableLines']}</td></tr>"
        for t in targets)

    file_sections = []
    for t in targets:
        rows = []
        # Impact order: most uncovered lines first (size x (1 - coverage)),
        # percentage as the tie-breaker.
        for f in sorted(t.get("files", []),
                        key=lambda f: (f["coveredLines"] - f["executableLines"], f["lineCoverage"])):
            name = html.escape(f["name"])
            rel = repo_relative(f.get("path", ""), repo)
            cell = (f'<a href="https://github.com/{repo}/blob/{sha}/{html.escape(rel)}">{name}</a>'
                    if rel else name)
            rows.append(
                f'<tr data-file="{name.lower()}"><td title="{html.escape(f.get("path", ""))}">{cell}</td>'
                f"<td><b>{f['executableLines'] - f['coveredLines']}</b></td>"
                f"<td>{pct(f['lineCoverage'])}</td><td>{bar(f['lineCoverage'])}</td>"
                f"<td>{f['coveredLines']}/{f['executableLines']}</td></tr>")
        file_sections.append(
            f"<details><summary><b>{html.escape(t['name'])}</b> — {pct(t['lineCoverage'])}, "
            f"{len(t.get('files', []))} files (most uncovered lines first)</summary>"
            f"<table><tr><th>File</th><th>Uncovered</th><th>Coverage</th><th></th><th>Lines</th></tr>{''.join(rows)}</table></details>")

    history_rows = "".join(
        f"<tr><td><span class=\"ts\" data-ts=\"{html.escape(p.get('ts', ''))}\">{html.escape(p['date'])}</span></td>"
        f"<td><a href=\"https://github.com/{repo}/commit/{html.escape(p['sha'])}\">{html.escape(p['sha'])}</a></td>"
        f"<td>{p['coverage']:.2f}%</td></tr>"
        for p in reversed(history[-30:]))

    page = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Mindbox iOS SDK — Code Coverage</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root {{ --bg: #ffffff; --fg: #1f2328; --muted: #666; --line: #eee; --track: #eee; --chart-bg: #fafafa }}
@media (prefers-color-scheme: dark) {{
  :root {{ --bg: #0d1117; --fg: #e6edf3; --muted: #8b949e; --line: #30363d; --track: #21262d; --chart-bg: #161b22 }}
}}
body {{ font: 14px -apple-system, sans-serif; margin: 2em auto; max-width: 880px; color: var(--fg); background: var(--bg) }}
a {{ color: #4493f8 }}
table {{ border-collapse: collapse; margin: 0.7em 0 }}
td, th {{ padding: 4px 12px; border-bottom: 1px solid var(--line); text-align: left }}
details {{ margin: 0.6em 0 }}
summary {{ cursor: pointer }}
input {{ font: inherit; padding: 5px 9px; width: 260px; border: 1px solid var(--line); border-radius: 6px;
         background: var(--bg); color: var(--fg) }}
button {{ font: inherit; padding: 5px 10px; border: 1px solid var(--line); border-radius: 6px;
          background: var(--bg); color: var(--fg); cursor: pointer }}
.big {{ font-size: 42px; font-weight: 700 }}
.muted {{ color: var(--muted) }}
.track {{ background: var(--track); border-radius: 3px; width: 120px; display: inline-block }}
.chart {{ background: var(--chart-bg); border: 1px solid var(--line) }}
</style></head><body>
<h1>Mindbox iOS SDK — Code Coverage</h1>
<p class="big">{pct(overall)}</p>
<p class="muted">{branch} @ <a href="https://github.com/{repo}/commit/{sha}">{sha}</a> &middot; <span class="ts" data-ts="{iso}">{date}</span> &middot; test bundles excluded</p>
<p class="muted">Export: <a href="coverage.csv" download="coverage-{sha}.csv">per-file CSV</a> &middot; <a href="history.json" download="history-{sha}.json">trend JSON</a></p>
<h2>Targets</h2>
<table><tr><th>Target</th><th>Coverage</th><th></th><th>Lines</th></tr>{target_rows}</table>
<h2>Trend</h2>
{trend_svg(history)}
<h2>Files</h2>
<p>
<input id="q" type="search" placeholder="Filter files&hellip;" oninput="filterFiles(this.value)">
<button onclick="setAll(true)">Expand all</button>
<button onclick="setAll(false)">Collapse all</button>
</p>
{''.join(file_sections)}
<h2>Recent deploys</h2>
<table><tr><th>Date</th><th>Commit</th><th>Total</th></tr>{history_rows}</table>
<script>
function setAll(open) {{
  document.querySelectorAll('details').forEach(d => d.open = open);
}}
document.querySelectorAll('.ts[data-ts]').forEach(el => {{
  const d = new Date(el.dataset.ts);
  if (!isNaN(d)) {{ el.title = el.textContent + ' (UTC)'; el.textContent = d.toLocaleString(); }}
}});
function filterFiles(query) {{
  const q = query.trim().toLowerCase();
  if (q) setAll(true);
  document.querySelectorAll('tr[data-file]').forEach(row => {{
    row.style.display = row.dataset.file.includes(q) ? '' : 'none';
  }});
}}
</script>
</body></html>
"""
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "index.html"), "w") as f:
        f.write(page)
    with open(os.path.join(outdir, "history.json"), "w") as f:
        json.dump(history, f, indent=1)
    write_csv(os.path.join(outdir, "coverage.csv"), targets, repo)
    print(f"coverage site: {pct(overall)} overall, {len(targets)} targets, "
          f"{len(history)} history points -> {outdir}/")


if __name__ == "__main__":
    main()
