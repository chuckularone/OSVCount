#!/bin/bash

# OSV Count Monitor Shell Script
# Fetches OSV data, processes it, and logs to daily file

# Configuration
SCRIPT_DIR="/scriptdir/osvcount"
LOG_FILE="$SCRIPT_DIR/data/osvcount.$(date +%Y%m%d).lst"

# Fetch the webpage
curl -s https://osvcount.com > "$SCRIPT_DIR/osvcount.out"

# Run the Perl processing script
"$SCRIPT_DIR/osvcount.pl"

# Read the values
COUNT=$(cat "$SCRIPT_DIR/osvcount.num" 2>/dev/null || echo "N/A")
STATE=$(cat "$SCRIPT_DIR/osvcount.state" 2>/dev/null || echo "N/A")
TIMESTAMP=$(date +%Y%m%d_%H:%M:%S)

# Append as comma-delimited line
echo "$COUNT,$STATE,$TIMESTAMP" >> "$LOG_FILE"
