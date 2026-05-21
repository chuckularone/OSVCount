# osvcount

Monitors the [Assateague Island OSV Count](https://osvcount.com) website, logs
vehicle counts over time, and generates a local HTML dashboard.

## Overview

Two cron jobs run every 30 minutes (offset by one minute) to fetch data and
rebuild the report:

```
05,35 * * * *  /scriptdir/osvcount/osvcount.sh   1>/tmp/osvcount.log 2>&1
06,36 * * * *  /scriptdir/osvcount/osvcountHTML.py 1>>/tmp/osvcount.log 2>&1
```

## Scripts

### `osvcount.sh`
Shell script — the entry point for each cron cycle.

1. Fetches `https://osvcount.com` and saves the raw HTML to `osvcount.out`.
2. Runs `osvcount.pl` to parse the HTML and update the state files.
3. Reads `osvcount.num` and `osvcount.state`, then appends a
   comma-delimited record to today's log file:

   ```
   <count>,<state>,<YYYYMMDD_HH:MM:SS>
   ```

### `osvcount.pl`
Perl script — parses `osvcount.out` and writes the state files.

Extracts:
- **Vehicle count** — the current number of vehicles on the beach
  → saved to `osvcount.num`
- **Open/closed status** — whether the OSV entrance is open or closed
  → saved to `osvcount.state`
- **"As of" timestamp** — the human-readable time shown on the site
  (e.g. `Thu, May 21 at 2:01 PM`) → saved to `osvcount.asof`
- **Vehicles in line** — number of vehicles queued at the OSV entrance
  → saved to `osvcount.inline`

Also fires an IFTTT webhook (URL read from `webhook.dat`) when the
status transitions from **closed → open**.

### `osvcountHTML.py`
Python script — reads today's log file and generates the HTML dashboard.

- Parses `data/osvcount.<YYYYMMDD>.lst`
- Reads `osvcount.asof` and `osvcount.inline` for the live site values
- Produces a matplotlib chart of vehicle count over time
- Writes the self-contained HTML report to:
  `/var/www/html/weatherdata/osvcount.html`

The count cell is highlighted:
| Count range | Color |
|-------------|-------|
| 120–139 | Yellow background |
| 140+ | Red background |

## File Layout

```
/scriptdir/osvcount/
├── osvcount.sh          # cron entry point
├── osvcount.pl          # HTML parser / state writer
├── osvcountHTML.py      # HTML report generator
├── webhook.dat          # IFTTT webhook URL (one line, no trailing newline)
├── osvcount.out         # latest raw HTML from osvcount.com
├── osvcount.num         # latest vehicle count (integer)
├── osvcount.state       # latest status: "open" or "closed"
├── osvcount.asof        # latest "As of" string from the site
├── osvcount.inline      # latest vehicles-in-line count
└── data/
    └── osvcount.YYYYMMDD.lst   # daily comma-delimited log
```

### Log file format

Each line in the daily `.lst` file:

```
<count>,<state>,<YYYYMMDD_HH:MM:SS>
```

Example:
```
16,open,20260521_14:05:01
```

## Dependencies

| Component | Dependency |
|-----------|-----------|
| `osvcount.sh` | `bash`, `curl` |
| `osvcount.pl` | Perl, `LWP::UserAgent` (`libwww-perl`) |
| `osvcountHTML.py` | Python 3, `matplotlib` |

Install Perl dependency:
```bash
sudo apt install libwww-perl
```

Install Python dependency:
```bash
pip install matplotlib
```

## Setup

1. Copy all files to `/scriptdir/osvcount/`.
2. Create the data directory:
   ```bash
   mkdir -p /scriptdir/osvcount/data
   ```
3. Create `webhook.dat` containing your IFTTT webhook URL:
   ```bash
   echo -n "https://maker.ifttt.com/trigger/..." > /scriptdir/osvcount/webhook.dat
   ```
4. Make the scripts executable:
   ```bash
   chmod +x /scriptdir/osvcount/osvcount.sh /scriptdir/osvcount/osvcount.pl \
             /scriptdir/osvcount/osvcountHTML.py
   ```
5. Add the cron entries (`crontab -e`):
   ```
   05,35 * * * *  /scriptdir/osvcount/osvcount.sh   1>/tmp/osvcount.log 2>&1
   06,36 * * * *  /scriptdir/osvcount/osvcountHTML.py 1>>/tmp/osvcount.log 2>&1
   ```

## Output

The dashboard is written to `/var/www/html/weatherdata/osvcount.html` and
auto-refreshes every 10 minutes. It displays:

- Open/closed status badge
- Most recent vehicle count (color-coded at thresholds)
- Vehicles in line at the OSV entrance
- "As of" timestamp sourced directly from the site
- Chart of vehicle count throughout the day
