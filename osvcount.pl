#!/usr/bin/perl
use strict;
use warnings;
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
my $WEBHOOK_FILE = "$BASE_DIR/webhook.dat";

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

# Trigger IFTTT webhook
sub trigger_webhook {
    my ($webhook_url) = @_;
    
    my $ua = LWP::UserAgent->new(timeout => 10);
    eval {
        my $response = $ua->post($webhook_url);
        if ($response->is_success) {
            print "✓ Webhook triggered successfully\n";
            return 1;
        } else {
            print "✗ Webhook failed with status: " . $response->status_line . "\n";
            return 0;
        }
    };
    if ($@) {
        print "✗ Webhook error: $@\n";
        return 0;
    }
}

# Main execution
sub main {
    # Read webhook URL from file
    unless (-e $WEBHOOK_FILE) {
        print "✗ Error: $WEBHOOK_FILE not found\n";
        return 1;
    }
    
    my $webhook_url = read_file($WEBHOOK_FILE);
    unless ($webhook_url) {
        print "✗ Error: Could not read webhook URL from $WEBHOOK_FILE\n";
        return 1;
    }
    
    print "✓ Loaded webhook URL from $WEBHOOK_FILE\n";
    
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
        print "! Status changed from CLOSED to OPEN - triggering webhook\n";
        trigger_webhook($webhook_url);
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
