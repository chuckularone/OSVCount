#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(mktime);
use Time::Local;
use LWP::UserAgent;
use File::Path qw(make_path);
use File::Basename;

# Configuration
my $BASE_DIR = "/scriptdir/osvcount";
my $HTML_FILE = "$BASE_DIR/osvcount.out";
my $STATE_FILE = "$BASE_DIR/osvcount.state";
my $COUNT_FILE = "$BASE_DIR/osvcount.num";
my $ASOF_FILE = "$BASE_DIR/osvcount.asof";
my $INLINE_FILE = "$BASE_DIR/osvcount.inline";
#my $WEBHOOK_FILE = "$BASE_DIR/webhook.dat";

# Read file contents
sub read_file {
    my ($filepath) = @_;
    return "" unless -e $filepath;
    open(my $fh, '<', $filepath) or return "";
    my $content = do { local $/; <$fh> };
    close($fh);
    $content =~ s/^\s+|\s+$//g;  # trim whitespace
    return $content;
}

# Write content to file
sub write_file {
    my ($filepath, $content) = @_;
    # Create directory if it doesn't exist
    my $dir = dirname($filepath);
    make_path($dir) unless -d $dir;

    open(my $fh, '>', $filepath) or die "Cannot write to $filepath: $!\n";
    print $fh $content;
    close($fh);
}

# Extract "As of" display string from the <time> tag text content
sub extract_asof {
    my ($html_content) = @_;
    if ($html_content =~ /<time[^>]*class="utc-time"[^>]*>([^<]+)<\/time>/) {
        return $1;
    }
    return undef;
}

# Extract vehicles in line count from fl-line section
sub extract_inline {
    my ($html_content) = @_;
    if ($html_content =~ /<div class="fl-line">.*?<div class="fl-number">(\d+)<\/div>/s) {
        return $1;
    }
    return undef;
}

# Extract OSV open/closed status
sub extract_osv_status {
    my ($html_content) = @_;

    if ($html_content =~ /<div class="close-o-meter">/) {
        return "open";
    } elsif ($html_content =~ /<div class="close-o-meter closed">/) {
        return "closed";
    }

    return undef;
}

# Extract vehicle count
sub extract_count {
    my ($html_content) = @_;

    if ($html_content =~ /<h1 class="current-count"><a href="\/history\/" id="fn-expired">(\d+)<\/a>/) {
        return $1;
    }

    return undef;
}


# Main execution
sub main {
    # Check if HTML file exists
    unless (-e $HTML_FILE) {
        print "✗ Error: $HTML_FILE not found\n";
        return 1;
    }

    # Read HTML file
    my $html_content = read_file($HTML_FILE);

    # Extract OSV status
    my $current_status = extract_osv_status($html_content);
    unless (defined $current_status) {
        print "✗ Error: Could not find OSV status in HTML\n";
        return 1;
    }

    print "Current OSV status: $current_status\n";

    # Read previous state
    my $previous_status = read_file($STATE_FILE);

    # Write current state
    write_file($STATE_FILE, $current_status);
    print "✓ Saved status to $STATE_FILE\n";

    # Check for state change from closed to open
    if ($previous_status eq "closed" && $current_status eq "open") {
        print "! Status changed from CLOSED to OPEN\n";
    } elsif ($previous_status && $previous_status ne $current_status) {
        print "Status changed from $previous_status to $current_status\n";
    }

    # Extract and save count
    my $count = extract_count($html_content);
    unless (defined $count) {
        print "✗ Error: Could not find vehicle count in HTML\n";
        return 1;
    }

    write_file($COUNT_FILE, $count);
    print "✓ Current count: $count vehicles (saved to $COUNT_FILE)\n";

    # Extract and save "As of" time string
    my $asof = extract_asof($html_content);
#
# adjust time for DST abd timezone
#
	my $input = $asof;
	
    # Determine Eastern offset (EST = -5, EDT = -4)
    # Use localtime with TZ set to America/New_York
    my $eastern_offset;
    {
        local $ENV{TZ} = 'America/New_York';
        POSIX::tzset();
        my @t = localtime(time);
        $eastern_offset = $t[8] ? -4 : -5;  # $t[8] is DST flag
        # Reset TZ
        POSIX::tzset();
    }
    # Parse the input string
    my %months = (
        Jan=>1, Feb=>2, Mar=>3, Apr=>4,  May=>5,  Jun=>6,
        Jul=>7, Aug=>8, Sep=>9, Oct=>10, Nov=>11, Dec=>12
    );
    
    my ($dow, $mon, $day, $hour, $min, $ampm) =
        $input =~ /^(\w+),\s+(\w+)\s+(\d+)\s+at\s+(\d+):(\d+)\s+(AM|PM)$/;
    
    # Convert to 24-hour
    $hour += 12 if $ampm eq 'PM' && $hour != 12;
    $hour  = 0  if $ampm eq 'AM' && $hour == 12;
    
    # Apply Eastern offset
    $hour += $eastern_offset;
    
    # Handle day rollover
    if ($hour < 0) {
        $hour += 24;
        # Adjust day of week
        my @days = qw(Sun Mon Tue Wed Thu Fri Sat);
        my %day_idx = map { $days[$_] => $_ } 0..$#days;
        $dow = $days[($day_idx{$dow} - 1 + 7) % 7];
        $day--;
    }
    
    # Convert back to 12-hour
    $ampm = $hour >= 12 ? 'PM' : 'AM';
    $hour = $hour % 12;
    $hour = 12 if $hour == 0;
    my $output = sprintf("%s, %s %d at %02d:%02d %s", $dow, $mon, $day, $hour, $min, $ampm);
    $asof = $output;
#
# End of DST timezone correction
#
    if (defined $asof) {
        write_file($ASOF_FILE, $asof);
        print "✓ As of: $asof (saved to $ASOF_FILE)\n";
    } else {
        print "✗ Warning: Could not find 'As of' time in HTML\n";
    }

    # Extract and save vehicles in line
    my $inline = extract_inline($html_content);
    if (defined $inline) {
        write_file($INLINE_FILE, $inline);
        print "✓ Vehicles in line: $inline (saved to $INLINE_FILE)\n";
    } else {
        print "✗ Warning: Could not find vehicles in line count in HTML\n";
    }

    return 0;
}
#
# Run main
exit main();


