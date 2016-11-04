#!/usr/bin/perl

use LWP::Simple;
use JSON qw( decode_json );
use JSON qw( encode_json );
use Data::Dumper;
use Getopt::Long;
use Switch;
use strict;
use warnings;

my $debug = 0;
sub debugPrint {
    if($debug > 0)
    {
        print "DEBUG: " . $_[0] . "\n";
    }
}

my $bridge = "";
my $user = "";
my $mode = "discovery";
my $lightid = "";
GetOptions("bridge=s" => \$bridge,
           "user=s" => \$user,
           "mode=s" => \$mode,
           "lightid=s" => \$lightid,
           "debug" => \$debug);

# Check that required fields were supplied
if($bridge eq "" or $user eq "") {
    print "Missing parameters.\n";
    help();
    exit 1;
}

sub help {
    print "Usage: hue.pl [--help] --bridge BRIDGE --user USER --mode MODE [--lightid LIGHTID]\n";
    print "Where BRIDGE  = Bridge IP or hostname\n";
    print "      USER    = Hue Bridge Username\n";
    print "      MODE    = discovery, bridgeinfo.*, or a hue light property name\n";
    print "      LIGHTID = Light ID for light properties\n";
}

sub getData {
    my $apipath = shift;
    my $url = "http://" . $bridge . "/api/" . $user . $apipath;
    my $json = get ($url) or die "Could not get $url!";
    return decode_json($json);
}

# Example discovery data
#{
#    "data": [
#        {
#            "{#SNMPINDEX}": "1",
#            "{#IFDESCR}": "WAN",
#            "{#IFPHYSADDRESS}": "8:0:27:90:7a:75"
#        },
#        {
#            "{#SNMPINDEX}": "2",
#            "{#IFDESCR}": "LAN1",
#            "{#IFPHYSADDRESS}": "8:0:27:90:7a:76"
#        },
#        {
#            "{#SNMPINDEX}": "3",
#            "{#IFDESCR}": "LAN2",
#            "{#IFPHYSADDRESS}": "8:0:27:2b:af:9e"
#        }
#    ]
#}


switch ($mode) {
    case "discovery" {
        debugPrint("Discovery Mode");
        # Get the list of all lights from the Hue Bridge
        my $hueData = getData("/lights");
        my @lights;
        my $key;
        my $value;
        while ( ($key, $value) = each %$hueData) {
            debugPrint "ID: " . $key;
            debugPrint "Name: " . $value->{'name'};
            debugPrint "Unique ID: " . $value->{'uniqueid'};
            debugPrint "Reachable: " . $value->{'state'}->{'reachable'};
            debugPrint "Light On: " . $value->{'state'}->{'on'};
            debugPrint "SWVersion: " . $value->{'swversion'};
            debugPrint "Model ID: " . $value->{'modelid'};
            debugPrint "\n";
            
            # Add a hash for the items we want to keep to an array:
            push @lights, {
                "{#UNIQUEID}" => $value->{'uniqueid'},
                "{#ID}" => $key,
                "{#NAME}" => $value->{'name'}
                };
        }
        my %discoveredlights;
        $discoveredlights{'data'} = \@lights;
        my $zabbixdata = encode_json \%discoveredlights;
        print $zabbixdata;
    }
    case /^bridgeinfo\..*$/ {
        debugPrint("Bridge Info Mode");
        my $bridgeInfo = getData("/config");
        #print Dumper $bridgeInfo;
        my($item) = $mode =~ /^bridgeinfo\.(.*)$/;
        debugPrint("Item: " . $item);
        print $bridgeInfo->{$item};
    }
    else {
        if($lightid =~ /^\d*$/) {
            # Try to get the value the light
            my $lightData = getData("/lights/" . $lightid);
            #print Dumper $lightData;
            if($mode =~ /.*\..*/) {
                # If the mode is blah.blah, separate the terms
                my($first) = $mode =~ /(.*)\..*/; 
                my($second) = $mode =~ /.*\.(.*)/; 
                debugPrint "First: " . $first;
                debugPrint "Second " . $second;
                if($lightData->{$first}->{$second} eq "true" or $lightData->{$first}->{$second} eq "false") {
                    my %boolint;
                    $boolint{"true"} = 1;
                    $boolint{"false"} = 0;
                    print $boolint{$lightData->{$first}->{$second}};
                }
                else {
                    print $lightData->{$first}->{$second};
                }
            }
            else {
                print $lightData->{$mode}
            }
        }
        else {
            print "ID not numeric";
        }
    }
}


#print Dumper $hueData;

# For discovery, return values name, uniqueid
# After discovery, return swversion, modelid
