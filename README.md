This is a utility that scrapes the osvcount.com website.
It collects the actual count of cars on the beach and the state (open/closed)

05,35 * * * *   /scriptdir/osvcount/osvcount.sh 1>/tmp/osvcount.log 2>&1
06,36 * * * *   /scriptdir/osvcount/osvcountHTML.py 1>>/tmp/osvcount.log 2>&1

It also creates a webpage to display the information it collects

