#!/usr/bin/env python3
"""
Generate an HTML report from /scriptdir/osvcount/data/osvcount.<YYYYMMDD>.lst

Output is saved to /var/www/html/weatherdata/osvcount.html
"""

import base64
import csv
import io
import os
from datetime import datetime, date
from typing import List, Tuple

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.ticker import MaxNLocator


def read_rows(path: str) -> List[Tuple[int, str, datetime]]:
    rows = []
    if not os.path.exists(path):
        raise FileNotFoundError(f"Input file not found: {path}")

    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.reader((ln.strip() for ln in f if ln.strip()))
        for parts in reader:
            try:
                if len(parts) != 3:
                    continue
                count_str, state, ts_str = [p.strip() for p in parts]
                count = int(count_str)
                ts = datetime.strptime(ts_str, "%Y%m%d_%H:%M:%S")
                rows.append((count, state, ts))
            except Exception:
                continue

    if not rows:
        raise ValueError(f"No valid rows parsed from {path}")

    rows.sort(key=lambda r: r[2])
    return rows


def make_plot_png(rows: List[Tuple[int, str, datetime]]) -> bytes:
    times = [r[2] for r in rows]
    counts = [r[0] for r in rows]

    fig = plt.figure(figsize=(9, 3.2), dpi=150)
    ax = plt.gca()
    ax.plot(times, counts, marker="o", linewidth=1.5, markersize=3)

    # Date-aware x-axis
    ax.xaxis.set_major_locator(mdates.AutoDateLocator(minticks=5, maxticks=10))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M"))

    ax.set_xlabel("Time (HH:MM)")
    ax.set_ylabel("Count")
    ax.yaxis.set_major_locator(MaxNLocator(integer=True))
    ax.grid(True, linewidth=0.3)
    fig.autofmt_xdate(rotation=45, ha="right")
    plt.tight_layout()

    buf = io.BytesIO()
    fig.savefig(buf, format="png", bbox_inches="tight")
    plt.close(fig)
    return buf.getvalue()


def build_html(latest_state: str, latest_count: int, latest_dt: datetime, chart_png_b64: str) -> str:
    pretty_time = latest_dt.strftime("%H:%M")
    pretty_date = latest_dt.strftime("%m/%d/%Y")

    # Determine conditional styling for count cell
    count_style = ""
    base_style = "font-weight: bold; font-size: 4em;"

    if 120 <= latest_count <= 139:
        count_style = f' style="{base_style} background-color: yellow; color: black;"'
    elif latest_count >= 140:
        count_style = f' style="{base_style} background-color: red; color: white;"'
    else:
        count_style = f' style="{base_style}"'


    return f"""<!doctype html>
<html lang="en">
<head>
<meta http-equiv="refresh" content="600">
<meta charset="utf-8">
<title>OSV Count Report</title>
<style>
  body {{ font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; margin: 0; padding: 24px; background: #f7f7f9; color: #111; }}
  .card {{ max-width: 800px; margin: 0 auto; background: #fff; border-radius: 14px; box-shadow: 0 6px 24px rgba(0,0,0,.08); padding: 24px; }}
  h1 {{ text-align: center; margin: 8px 0 18px; font-size: 2rem; letter-spacing: .5px; }}
  table {{ margin: 0 auto 18px; border-collapse: collapse; min-width: 260px; }}
  th, td {{ border: 1px solid #e5e7eb; padding: 10px 14px; text-align: center; }}
  th {{ background: #fafafa; font-weight: 600; }}
  .badge {{ display: inline-block; padding: 7px 14px; border-radius: 999px; font-weight: 700; letter-spacing:.3px; }}
  .badge.open {{ background: #e6ffed; color: #036b26; border: 1px solid #a7f3d0; }}
  .badge.closed {{ background: #fff1f2; color: #9f1239; border: 1px solid #fecdd3; }}
  .chart {{ display: block; max-width: 100%; height: auto; margin-top: 10px; }}
  .muted {{ color: #6b7280; font-size: .9rem; text-align:center; margin-top: 4px; }}
</style>
</head>
<body>
  <div class="card">
    <h1><span class="badge {latest_state.lower()}">{latest_state.upper()}</span></h1>
    <table>
      <thead><tr><th>Most Recent Count</th></tr></thead>
      <tbody><tr>
        <td{count_style}>{latest_count}</td>
      </tr>
      <tr>
        <td>{pretty_date} @ {pretty_time}</td>
      </tr></tbody>
    </table>
    <img class="chart" alt="Count vs Time" src="data:image/png;base64,{chart_png_b64}">
    <div class="muted">Count over time (x-axis shows times only).</div>
  </div>
</body>
</html>"""


def main():
    today = date.today().strftime("%Y%m%d")
    input_path = f"/scriptdir/osvcount/data/osvcount.{today}.lst"
    output_path = f"/var/www/html/weatherdata/osvcount.html"

    rows = read_rows(input_path)
    latest_count, latest_state, latest_dt = rows[-1]
    png_bytes = make_plot_png(rows)
    b64 = base64.b64encode(png_bytes).decode("ascii")
    html = build_html(latest_state, latest_count, latest_dt, b64)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"Wrote {output_path}")
    print(f"Latest: state={latest_state} count={latest_count} at {latest_dt:%H:%M %m/%d/%Y}")


if __name__ == "__main__":
    main()
