#!/usr/bin/perl
# 
# Package to craft and send the HTTP requests
# by chr1x & nitr0us
# 

package DotDotPwn::HTTP;
use Exporter 'import';
@EXPORT = qw(FuzzHTTP);

use DotDotPwn::BisectionAlgorithm;

use HTTP::Request;
use LWP::UserAgent;
use Time::HiRes qw(usleep);

sub FuzzHTTP{
	my ($host, $port, $method, $bisection_request, $ssl) = @_;
	our $n_travs = 0;
	my $false_pos = 0;
	my $foo = 0; # Used as an auxiliary variable in quiet mode (see below)
	my $UserAgent;

	open(AGENTS, "DotDotPwn/User-Agents.txt") or die "[-] Cannot open User-Agents.txt file: $!";
	my @UserAgents = <AGENTS>;
	close(AGENTS);

	if(!$bisection_request){
		open(REPORT , ">>$main::report");
	}

	foreach my $traversal (@main::traversals){
		my $http = LWP::UserAgent->new();

		$UserAgent = @UserAgents[int(rand(@UserAgents))];
                my $request = new HTTP::Request $method, '' . ($ssl ? "https://" : "http://") . "$host" . ($port ? ":$port" : "") . "/" . $traversal;
		$UserAgent =~ s/[\r\n]//g;
                $request->header('User-Agent', $UserAgent);

		# Return 1 (vulnerable) or 0 (not vulnerable) to BisectionAlgorithm()
		if($bisection_request){
			$http->request($bisection_request);

			if($http->status() == 200){
				if($main::pattern){
					if($http->body() =~ /$main::pattern/s ){
						return 1; # Vulnerable
					} else {
						return 0; # Not Vulnerable
					}
				} else {
					return 1; # Vulnerable
				}
			} else {
				return 0; # Not Vulnerable
			}
		}

		#my $request = new HTTP::Request $method, "http://$host" . ($port ? ":$port" : "") . "/" . $traversal;
                #$request->header('User-Agent', $UserAgent);
                my $response = $http->request($request);
		if(!$response){
			my $runtime = time - $main::start_time;
			for my $fh (STDOUT, REPORT) {
				print  $fh "\n[+] False positives detected: $false_pos" if $false_pos > 0;
				printf $fh "\n[+] Fuzz testing finished after %.2f minutes ($runtime seconds)\n", ($runtime / 60);
				print  $fh "[+] Total Traversals found (so far): $n_travs\n";
			}
			die "[-] Web server ($host) didn't respond !\n";
		}

		if($response->code == 200){
			if($main::pattern){
				if($http->body() =~ /$main::pattern/s ){
					for my $fh (STDOUT, REPORT) { print $fh "\n[*] Testing Path (response analysis): $request <- VULNERABLE!\n"; }
					$n_travs++;

					if($main::bisect){
						print "\n[========= BISECTION ALGORITHM  =========]\n\n";
						DotDotPwn::BisectionAlgorithm::BisectionAlgorithm(1, $main::bisdeep, $request);

						return 1;
					}

					return $n_travs if $main::break;
				} else {
					if($main::quiet){
						print ". " unless $foo++ % $main::dot_quiet_mode;
					} else {
						print "\n[*] Testing Path: $request <- FALSE POSITIVE!\n";
					}

					$false_pos++;
				}
			} else {
				for my $fh (STDOUT, REPORT) { print $fh "\n[*] Testing Path: $request <- VULNERABLE!\n"; }
				$n_travs++;

				if($main::bisect){
					print "\n[========= BISECTION ALGORITHM  =========]\n\n";
					DotDotPwn::BisectionAlgorithm::BisectionAlgorithm(1, $main::bisdeep, $request);

					return 1;
				}

				return $n_travs if $main::break;
			}

			usleep($main::time);
			next;
		}

		if($main::quiet){
			print ". " unless $foo++ % $main::dot_quiet_mode;
		} else{
			print "[*] HTTP Status: " . $response->code . " | Testing Path: ".$request->uri."\n";
		}

		usleep($main::time);
        }

	for my $fh (STDOUT, REPORT) { print $fh "\n[+] False positives detected: $false_pos" if $false_pos > 0; }

	return $n_travs;
}
