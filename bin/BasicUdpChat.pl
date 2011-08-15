#!/usr/bin/perl -w
# Basic UDP Chat in perl
# Michael Renz <cryptographrix@gmail.com>
#
# Exit codes:
# None yet.  I'll list them here
#
# Exit messages:
# Again, None yet.  They will be here, as well.
#

# Relatively basic modules.
# If you don't have them, try doing:
# $ cpan install IO::Socket
# $ cpan install threads
use strict;
use IO::Socket;
use threads ('yield',
                 'stack_size' => 64*4096,
                 'exit' => 'threads_only',
                 'stringify');
use threads::shared;

# peers array.  This is kinda important...for now.
my @peers :shared;

# Dependency on curl.  Dear God I'm sorry....for now.
my $externalIP = `curl http://automation.whatismyip.com/n09230945.asp 2>/dev/null`;

sub SetItUp {
	# This is included for modularity.  It basically sets up the first peer.
	print "Basic UDP Chat\n";
	print "cat this file to see the comments.\n\n";

	print "Give me a hostname or IP to start with: ";
	my $firstpeer = <>;
	chomp($firstpeer);
	until ($firstpeer) {
		print "I did not receive a hostname or IP.  If you do not enter one, this node will be receive-only until it hears from someone else.\n";
		print "Enter 'OVERRIDE' if you are ok with this.  The default hub is hub.nft.ag.\n";
		print "Otherwise, please re-enter the hostname or IP:";
		$firstpeer = <>;
		chomp($firstpeer);
	}

	if (!($firstpeer =~ /OVERRIDE/)) {
		$peers[0] = $firstpeer;
	}

	print "\nThank you!  You are now sending over UDP!\n";
}

sub sendMessage {
	# This sub actually sends the messages

	# Currently broadcasts to every @peers
	my ($tobesent) = @_;

	foreach my $remote (@peers) {
		my $message = IO::Socket::INET->new(Proto=>"udp",PeerPort=>5000,PeerAddr=>$remote)
        	        or die "Can't make UDP socket: $@";

        	$message->send($tobesent) or die "Send error: $!\n";
	}
}	

sub send_thread {
	# This is the thread that grabs user input

	# I like to loop forever.  Ctrl-C out until I add in switch cases.
        while (1) {
                my $tosend	= <>;
		chomp($tosend);			# If you don't enter anything, we'll chop out your newline.
		if ($tosend) {			# And we'll also do nothing if you just hit enter.
                	sendMessage($tosend);	# Otherwise, we'll send whatever you type in.
		}
        }
}


sub receive_thread {
	# This is the thread that prints out whatever comes in on the LocalPort
        my $response = IO::Socket::INET->new(Proto=>"udp",LocalPort=>5000)
                or die "Can't make UDP server: $@";

	# I like to loop forever.  Again.
        while (1) {
                my ($datagram,$flags);
                $response->recv($datagram,42,$flags);
                print $response->peerhost,": $datagram\n";
		if (!( grep { $_ eq $response->peerhost } @peers )) {
			push @peers, $response->peerhost;
		}
        }
}

# This is where stuff actually happens.
SetItUp();
my $rthr = threads->create('receive_thread');
my $sthr = threads->create('send_thread');
$sthr->join();
