#!/usr/bin/perl

	use strict;
	use warnings;

	no warnings qw( redefine );
	use utf8::all;
	use warnings qw/ FATAL utf8 /;
	use open qw/ :std :utf8 /;
	use 5.020;

	use String::Util qw/ hascontent trim /;
	# use Text::Filter;
	use Cwd;
	use File::Find;
	# use Text::Table;
	use Term::ANSIColor qw/ :constants /;
	# use Text::ANSITable
	# use File::Find::Rule;
	use String::Util;
	use Data::Dumper;
	use Ref::Util qw/ is_hashref is_arrayref /;
	use Hash::Util qw/ hash_locked unlock_value lock_value /;
	use File::stat qw(:FIELDS);
	# use FileHandle;
	# use English;
	# use Search::Elasticsearch;
	# use Config::IniFiles;
	# use Time::HiRes qw/ gettimeofday /;



	my %configured;
	BEGIN {
		sub readconfig {
			my @recepisse;
			while ( my $data_string = <DATA> ) {
				$data_string = trim $data_string;
				next unless ( hascontent( $data_string ) );
				push @recepisse , map { trim $_ } split( /:|,/, $data_string );
			}
			%configured = @recepisse;
			$configured{TOTAL} = 0;
			hash_locked( %configured );
			# print "\nCONFIGURATION : "; print Dumper \%configured;
		} # End of sub

	}  # End of BEGIN


	sub linehere {
	   print "\n--------------------------------------------------------------";
	} # End of sub



	sub changeconfigdir {
		my ( $conf, $subd ) = @_;
		unless (( @ARGV eq 2 ) || ( is_hashref( $conf )) || ( -d $subd )) {
					die "\nIncorrect number or type of arguments : $!";
		}
		my $curdir = getcwd;
		$$conf{LOGDIRECTORY} = "$curdir/$subd";
		chdir $configured{LOGDIRECTORY};
		print "\nNew directory : $configured{LOGDIRECTORY}\n";
		return $conf;
	} # End of sub;


	sub readit {
		# use File::Find;
		my $subdirs = shift;
		$subdirs = trim($subdirs);
		my $subd = $subdirs;
		if ( defined $subdirs ) {
			$subd =~ s/^\///;
			if ( -d $subd )  {
				my $conf_ref = changeconfigdir( \%configured, $subd );
				showdircontents( $conf_ref, $subd );
				return 0;
			}
			elsif ( -f $subd ) { return 1; }
			else { return undef; }
		}
		else {
			$subdirs = '';
		}
		return showdircontents( \%configured, $subdirs );
	} # End of sub


	sub showdircontents {
		my $realbigfile = $_[0];
		my ( $config , $subd ) = @_;
		unless (( @ARGV eq 2 ) || ( is_hashref( $config )) || ( -d $subd )) {
					die "\nIncorrect number or type of arguments : $!";
		}
		opendir my $dirhandle, "$$config{LOGDIRECTORY}"
			or die "Can't open < $$config{LOGDIRECTORY} : $!";
		my @logdir = readdir($dirhandle);
		my @cleanlogdir;
		my @splitlogdir = split / /, "@logdir";
		my @cleanup = grep { not /^\s?\.{1,2}\s?$|\.gz/m } @splitlogdir;
		@cleanlogdir = grep { not /\.\d|\.gz/ } @cleanup;
		push @cleanlogdir, '..';
		displayit( \@cleanlogdir );
		close $dirhandle;
		return 1;
	} # End of sub


	sub finddirs {
		use File::Find::Rule;
		my $dir = shift;
    		my @subdirs = File::Find::Rule->directory->in( $dir );
		my @arr;
		for ( @subdirs ) { push @arr, split( /\b$dir\b/m, $_ ); }
		my $expr = qr{^$dir/|^$dir/};
		no warnings;	# hard to avoid 'Useless use of string in void context'
		my @current = map { " $_ "; $_ =~ s/$expr//; $_ } @arr;
		# print "\n".uc($dir)." : @current         TOTALS : ".@current."\n";
		return \@current;
	} # End of sub


	sub extractpwd {
		my $paths = shift;
		my @arr; my %check;
		for ( @$paths ) {
		        my ( $pwd, $rest ) = split( /\.+\//, $_ );
	       		my @pwd2 = split( /\//, $pwd );
			push @arr, $pwd2[0] unless ( $check{$pwd2[0]} );
	        	$check{$pwd2[0]} = 1;
		}
		# print "\nPWD : @arr                      TOTALS : ".@arr."\n";
		return \@arr;
	} # End of sub


	sub colorit  {
		use Text::ANSITable;
		my $filename = shift;
		my $pwdarray = extractpwd( finddirs( $configured{LOGDIRECTORY} ) );
		my @dirarray;
		foreach my $tested ( @$pwdarray ) {
			my $filesize = -s $tested;
			# next if ( 10 > $filesize );
			push @dirarray, $tested if ( -d $tested );
		}
		# print "\nDIRARRAY : @dirarray ,    FILE : $filename \n";
		return \@dirarray;
	} # End of sub


	sub displayit  {
		use Text::ANSITable;
		my $dirs = shift;
		binmode(STDOUT, ":utf8");
		my $realbigfile = $_[0];
		my $tb = Text::ANSITable -> new();
		my $count = 0; my @loader;
		my $no = scalar @$dirs;
		$tb -> columns([ "Log Directory :", "$configured{LOGDIRECTORY}" , " "]);
		$tb -> cell_width( 20 );
		my @sorted = sort { $a cmp $b } @$dirs;
		foreach my $item  ( @sorted )  {
			$item = ( $count == 2 ) ? "$item" : "$item,";
			my $dirarray = colorit( $item );
			my $ansa = grep { $item =~ /$_/ } @$dirarray;
		       	$item = "/$item" if ( $ansa );
			if ( $configured{FASTSPEED} )  {
				# conditional sub{ $ansa } not working per cell: module BUG.
				$tb-> add_cond_cell_style( sub { 1  }, fgcolor=>'ffffff', bgcolor=>'202020' );
			}
			push( @loader, $item );
		        next unless ( (0 == ++$count % 3) || ($count > $no -3) );
			$tb -> add_row( [@loader] );
			$count = 0;
			@loader = ();
		}
		# print "\nDUMPED : "; print Dumper $tb;
		return print $tb -> draw;
	} # End of sub


	sub eitherorhelper {
		my ( $alt ) = @_;
		my $alternative = $alt;
		my $altstring = join '', map { $_ } @$alternative;
		if ( $altstring =~ m/&/o ) { $altstring =~ s/[&]+/ and /g; return $altstring; }
		$altstring =~ s/[\|]+/ or /g;
		return $altstring;
	} # End of sub


	sub trier {
		use English;	
	   	my ( $chunks, $info ) = @_;
		my $boss = ( caller(1) )[3];		
		my $display = ( $boss =~ m/displaymore/ ) ? 1 : 0;
	   	my $additive = grep { /&&/g } @$info;  	   
	   	my $query = ( $additive ) ? 
				join( '', grep { s/&&/|/g } (@$info) ) : 
						join( '|', grep { $_ } (@$info) );	     
	   	my $pattern = qr/$query/p;         	
	   	my @found;
		foreach my $line ( @$chunks ) {   
			chomp $line; 			  
			my @allmatches = $line =~ m/$pattern/g;  	
			next unless ( ${^MATCH} );
			my @newline; my %condense;
			@condense{@allmatches} = ();
			if ( $additive ) { next if ( $additive > keys(%condense) - 1 ); }
			foreach my $hit ( keys %condense ) {  			        
				my @replaces = ( $display ) ? map { trim($_) } (BOLD,CYAN,$hit,RESET) :
										map { trim($_) } ("**".$hit."**");
				@newline = map { s/$hit/@replaces/rmg } ( $line );
				$line = "@newline";						
			}
			push @found, join( '', grep { s/^\s+/      /m } @newline );    
		}
	   	return \@found;
	} # End of sub


	sub displaymore {
		# use Term::ANSICOLOR qw / :constants /;
		my ( $chunks, $log, $total, $info ) = @_;
		return 0 unless ( is_arrayref( $info ));
		my $choice = eitherorhelper( $info );
		unless ( defined $chunks ) {
			       	print BOLD, BLUE, "\n No occurrences of '".$choice."' found in $log.\n", RESET;
		       		sleep 6; exit;
		}
		my $elements = ( $total ) ? $total : scalar @$chunks;
		push my @found, BOLD, BLUE, "   Search for : '",RESET,BOLD, WHITE,$choice, RESET,
								BOLD, BLUE, "' in Log : $log  @", RESET;
		push @found, BOLD, BLUE, &getloggingtime, RESET;
		push @found, BOLD, BLUE, "   Log entries retrieved : ", RESET;
		push @found, BOLD, WHITE, " $elements\n\n", RESET;
		my $textdiscount = scalar @found;
		my $highlights = trier( $chunks, $info );
		push @found, map { $_ } @$highlights;  
		my $elements2 = scalar @found - $textdiscount;
	        push @found, BOLD, BLUE, "\n   No. of Log entries filtered :  ", RESET;
		push @found, BOLD, WHITE, $elements2, RESET;
		my $percent = ( $elements2 > 0 ) ? $elements2 * 100 / $elements : 0;
		$percent = sprintf( "%.2f", $percent );
		push @found, BOLD, BLUE, " or ".$percent." per cent", RESET;
		print @found;
		return \@found;
	} # End of sub


	sub printmore  {
		my ( $chunks, $log, $total, $info ) = @_;
		return 0 unless ( is_arrayref( $info ));
		my $choice = eitherorhelper( $info );
		unless ( defined $chunks ) {
		       	print BOLD, BLUE, "\n No occurrences of '$choice' found in $log.\n", RESET;
	       		sleep 6; exit;
	 	}
		my $elements = ( $total ) ? $total : scalar @$chunks;
		my $no1 = "   Log entries retrieved : $elements\n\n";
		push my @found, "\n   Search for : '".$choice."' in Log : $log  \@".&getloggingtime.$no1;
		my $textdiscount = scalar @found;
		my $highlights = trier( $chunks, $info );
		push @found, map { $_ } @$highlights;  
		my $elements2 = scalar @found - $textdiscount;
		my $no3 = "\n   No. of Log entries filtered :  ";
		my $percent = ( $elements > 0 ) ? $elements2 * 100 / $elements : 0;
		$percent = sprintf( "%.2f", $percent );
		push @found, "$no3 $elements2 or $percent per cent.\n\n";
		return \@found;
	} # End of sub


	sub getloggingtime {
    		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    		my $nice_timestamp = sprintf ( "%04d%02d%02d %02d:%02d:%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    		return "$nice_timestamp";
	} # End of sub


	sub getmonthname {
		my @mth = localtime(time);
		my %cal = (	0 => 'Jan',
				1 => 'Feb',
				2 => 'Mar',
				3 => 'Apr',
				4 => 'May',
				5 => 'Jun',
				6 => 'Jul',
				7 => 'Aug',
				8 => 'Sep',
				9 => 'Oct',
				10 => 'Nov',
				11 => 'Dec' );
		my $realbigfile = $_[0];
		my $effectivemonth = $mth[4] + $configured{MONTHAGO};
		my $mmm = $cal{$effectivemonth};
		return $mmm;
	} # End of sub


	sub getyear {
		my @year = localtime(time);
		return $year[5] + 1900;
	} # End of sub


	sub getweekdays {
		my $select = shift // 'today';
		if ( $select =~ m/^today/ ) { return (localtime(time))[6]; }
		return ('Mon', 'Tue', 'Wed', 'Thu','Fri', 'Sat', 'Sun');
	} # End of sub


	sub getlastpath {
		my $newpath = shift;
		return sub { shift()."\/$newpath" };
	} # End of path


	sub getlogfilename  {
		my $logname = shift;
		$logname = trim( $logname );
		$logname = lc( $logname );
		return $logname if ( $logname =~ /\w+\.log$|^\/\w+/ );

		my %selector = (
				xorg => 'Xorg.0.log',
				vnetlib => 'vnetlib',
				syslog => 'syslog',
				dovecot => 'dovecot.log',
				auth => 'auth.log',
				'/audit' => './audit',
				freshclam => 'freshclam.log',
				'mail.err' => 'mail.err',
				'mail' => 'mail.log',
				monit => 'monit.log',
				'/mysql' => './mysql',
				error => 'error.log',
				'/upgrade' => './upgrade',
				'/cups' => './cups',
				zeyple => 'zeyple.log',
				' ' => sub { die "\nLog name not specified. Please check!\n"; },
			       );

		my $ret = $selector{$logname};
		unless ( defined $ret ) {
			print BOLD, BLUE,
				"\nThis logfile has not been provided for in getlogfilename().\n", RESET;
			sleep 6; return 0;
		}
		return getlastpath() unless ( $logname );
		return getlastpath()->( $ret );
	} # End of sub


	sub retrieveconfig {
		use Config::IniFiles;
		# reading configuration details from config-ini.pl: use Config::IniFiles;
		my $ini = Config::IniFiles -> new( -file  => "$configured{CONFIGFILE}config-ini.pl" )
								or die "Could not open config-ini.pl : $!";
		my $syslogkey = $ini -> val( 'CRITERION', 'syslog');
		my $auditkey = $ini -> val( 'CRITERION', 'audit');
		my $freshclamkey = $ini -> val( 'CRITERION', 'freshclam');
		my $mysqlkey = $ini -> val( 'CRITERION', 'mysql');
		my $monitkey = $ini -> val( 'CRITERION','monit');
		my $Xorg0key = $ini -> val( 'CRITERION','Xorg0');
		my $zeyplekey = $ini -> val( 'CRITERION','zeyple');

		my $outdir = $ini -> val( 'OUTPUT', 'directory' );
		unlock_value( %configured, 'OUTPUTTO' );
		$configured{OUTPUTTO} = $outdir if ( $outdir );
		my $confdir = $ini -> val( 'CONFDIR', 'config' );

		unlock_value ( %configured, 'CONFIGFILE' );
		$configured{CONFIGFILE} = $confdir if ( $confdir );
		lock_value( %configured, 'CONFIGFILE' );

		return [ $syslogkey,$auditkey,$freshclamkey,$mysqlkey,$monitkey,$Xorg0key,$zeyplekey ];
	} # End of sub


	sub searchconfig  {
		my $searched = shift;
		unless ( $searched ) { die "\nNo search terms specified: terminating here. $!\n"; }
		my $junction = ( $searched =~ /and|\+|&/io ) ? '&' : '|';
		$searched =~ s/and|\+|[&]+//gi;
		my  $searches = [ trim( join( $junction, split( / /, $searched )) ) ];
		# @{  $searches }[-1] =~ s/\|{1}$//o;
		return $searches;
	} # End of sub



	sub getlogsearchdrivers  {
		use Config::IniFiles;
		my ( $fulllogname, $searches ) = @_;
		unless ( @$searches ) { die "\nNo search terms specified: terminating here. $!\n\n"; }
		unless ( $fulllogname ) { die "\nNo log specified: terminating here, line ",__LINE__,".\n\n"; }

		my ( $logname, $suffix ) = split( /\./, $fulllogname );
		if (( $suffix ) && ( $suffix =~ /err|warn/ )) { $logname = "$logname.$suffix"; }
		chomp $logname;

		my $year = getyear();
		my $mth = getmonthname();
		my $wday = getweekdays( 'today' );

		my $ret = retrieveconfig();
		my ( $syslogkey,$auditkey,$clamkey,$mysqlkey,$monitkey,$Xorg0key,$zeyplekey ) = map { $_ } @$ret;

		# these split regex keys need to be in all log entries in a given log at the start
		# pls amend or add to local log features
		my $syslogfilter = ( $syslogkey ) ? $syslogkey : $mth;
		my $auditfilter = ( $auditkey ) ? $auditkey : 'type=';
		my $freshclamfilter = ( $clamkey ) ? $clamkey : $wday;
		my $mysqlfilter = ( $mysqlkey ) ? $mysqlkey : "$year-";
		my $monitfilter = ( $monitkey ) ? $monitkey : '\[CEST';
		my $Xorg0filter = ( $Xorg0key ) ? $Xorg0key : '\[\s\b';
		my $zeyplefilter = ( $zeyplekey ) ? $zeyplekey : "$year-";

		my %filterdispatch = (
					syslog => [ qr/$syslogfilter/, $searches ],
					vnetlib => [ qr/$syslogfilter/, $searches ],
					auth => [ qr/$syslogfilter/, $searches ],
					audit => [ qr/$auditfilter/, $searches ],
					'mail.err' => [ qr/$syslogfilter/, $searches ],
					mail => [ qr/$syslogfilter/, $searches ],
					dovecot => [ qr/$syslogfilter/, $searches ],
					freshclam => [ qr/$freshclamfilter/, $searches ],
					monit => [ qr/$monitfilter/, $searches ],
					error => [ qr/$mysqlfilter/, $searches ],
					Xorg => [ qr/$Xorg0filter/, $searches ],
					zeyple => [ qr/$zeyplefilter/, $searches ],
					_default_  => [ qr/\R/m, $searches ],
			   	     );
		my $realbigfile = $_[0];

		my $input = $filterdispatch{$logname};
		return $input;
	}  # End of sub



	# Ref.: https://metacpan.org/pod/distribution/MCE/lib/MCE.pod thanks again, Mario Roy
	sub hugefilter {
		use MCE::Loop;
		my ( @in ) = @_;
		unless (( 3 >= scalar @in ) && ( 1 < scalar @in )) {
			warn "\nIncorrect number of inputs to hugefilter() sub, line ", __LINE__,".";
			sleep 5; die;
		}
		{
			no warnings qw/ void /;
			my $trouvaille = "(hugefilter() line ", __LINE__, " ).\n\n";		
			unless ( -r $_[0] ) { die "\nNo readable file supplied as ARGV[0] $trouvaille"; }
			unless ( -s $_[0] ) {    
				die "\nFile supplied as ARGV[0] non-existent $trouvaille\n" if( $! );
				warn "\nEmpty file supplied as ARBGV[0] $trouvaille\n";
				return $_[0];
			}
			unless ( is_arrayref( $_[1] )) {
				die "\nNo proper array ref as ARGV[1] (hugefilter() line ", __LINE__,".\n\n";
			}
		}
		my ( $splitter, $patterns ) = map { $_ } @{ $_[1] };
		my $search = join( '|', map { $_ } @$patterns );
		my $realbigfile = $_[0];

		my $totality = sub { 	MCE::Loop::init { chunk_size => 1, use_slurpio => 1 };
					unlock_value( %configured, 'TOTAL' );
					$configured{TOTAL} = mce_loop_f  {
						my ( $mce, $slurp_ref, $chunk_id ) = @_;
						my $out = grep { /$splitter/g } ( $_ );
						MCE -> gather( + $out );
					} $realbigfile;
					lock_value( %configured, 'TOTAL' );
				   };  # End of MCE_loop_f1

		my $firstrun;
		# run only once at start
		$firstrun = $totality -> () unless ( $configured{TOTAL} && hascontent $_[2] );

		my @result;
		{ 	# MCE scope to isolate inputs to mce_loop_f

	 		MCE::Loop::init { max_workers => 8, use_slurpio => 1 };
			my $hugefile = $_[0];

			@result = mce_loop_f {
	    			my ( $mce, $slurp_ref, $chunk_id ) = @_;

				# Process the slurped chunk only if true.
	    			if ( $$slurp_ref =~ /$search/m ) {
	       				my @matches;
					if ( $^O =~ m/nix$|linux/io )  {
	       					# The following is fast on Unix, but performance degrades
	       					# drastically on Windows beyond 4 workers.
	       					open my $MEM_FH, '<', $slurp_ref;
	       					binmode $MEM_FH, ':raw';
	       					while (<$MEM_FH>) {
							push @matches, "     $_\n\n" if ( /$search/ );
						}
	       					close   $MEM_FH;

					}
					elsif ( $^O =~ m/win/io )  {
	       					while ( $$slurp_ref =~ /([^\n]+\n)/mg ) {
		  					my $line = $1; # save $1 to not lose the value
		  					push @matches, "     $line\n" if ($line =~ /$search/);
	       					}
					}
					else {
						print "\n$^O is not supported in hugefile() line ",__LINE__,"\n\n";
						exit;
					}
	       				MCE->gather(@matches);
	    			}
	 		} $hugefile;
		} # End of MCE_loop2 scope

		return \@result if ( hascontent $_[2] && $_[2] =~ m/nodisplay/o );
		my @resultcopy = @result;
		displaymore( \@result, $_[2]->[0], $configured{TOTAL}, $_[2]->[1] );
		return printmore( \@resultcopy, $_[2]->[0], $configured{TOTAL}, $_[2]->[1] );
	} # End of sub


	sub additivefilter {
		my ( $fullpath, $details ) = @_;
		my ( $splitter, $patterns ) = map { $_ } @$details;
	     	my @search = split( /&&/, "@$patterns" );
		my $truepath = $fullpath;
		my $inmemory;     				
		while ( scalar @search ) {
			my $item = shift @search;
		        next if ( $item =~ m/[&|]+/g );
			$fullpath = $inmemory unless ( $fullpath );
			my $latestinput = hugefilter( $fullpath, [ $splitter, [$item] ], 'nodisplay' );
			$inmemory = "$configured{CONFIGFILE}shortmemory.txt";  # file fastest in MCE
			open ( my $fh, '+>', $inmemory ) or die "\nFile could not be opened : $! \n\n";
			print $fh @$latestinput;
			close $fh,
			$fullpath = 0;
			next if ( scalar @search -1 );
			return hugefilter( $inmemory, [ $splitter, [$item] ], [ $truepath, $patterns ] );
		}
	} # End of sub



	# TBD ...or another compatible text search engine. Objective: weighted, more complex searches, speed
	sub elasticfilter  {
		# use Search::Elasticsearch;
		my ( @in ) = @_;
		unless ( 2 == scalar @in ) {
			warn "\nIncorrect number of inputs to elasticfilter() sub, line ",  __LINE__, ".";
			sleep 5; die;
		}

		my ( $splitter, $patterns ) = map { $_ } @{ $_[1] };
		my ( $search ) = map { $_ } @$patterns;


	} # End of sub



	sub nofilter  {
		my @in = @_;
		unless ( 2 == scalar @in ) {
			warn "\nIncorrect number of inputs to nofilter() sub, line ", __LINE__, ".";
			sleep 5; die;
		}
		my $fulllogname = $_[0];
		chomp $fulllogname;

		my ( $splitter, $patterns ) = map { $_ } @{ $_[1] };
		my ( $search ) = map { $_ } @$patterns;   # not used here

		print "\nSmall text file warrants little overhead. Sub nofilter() used for $_[0] !\n\n";

		my @output;
		{
			use FileHandle;
			local $/ = undef;
			open( my $logh, '+<', $fulllogname )
							  or die "Can't open < $fulllogname : $!";
			# $logh -> autoflush(1);
			while ( my $line = <$logh> ) {
				push @output, $line if ( $line =~ /$search/g );
			}
		}

		unshift @output, BOLD, BLUE, "   This log file is short. ", 
						"Perhaps looking at it in full does the job?",
						 "\nIf required, help yourself to a full copy: \n\n", RESET;
		push @output, "\n\n";   
		my @resultcopy = @output;
		displaymore( \@output, $_[0], $configured{TOTAL}, $patterns );
		return printmore( \@resultcopy, $_[0], $configured{TOTAL}, $patterns );
	} # End of sub



	########################################### start of main routine #########################################

	&linehere;
	readconfig();
	chdir $configured{LOGDIRECTORY};

	my $lang;
	my $typein = sub  {
			RE:
			print "\n\nCurrent log directory : ", getcwd, "\n";
			print "\n\nFiltering Log for following phrase:\n\n   > ";
			$lang = <STDIN>;
			print "\n\n";
			$lang = trim($lang);
			unless ( hascontent($lang) ) {
				print BOLD, BLUE, "No string supplied. Try again!\n", RESET;
				sleep 2;
				goto RE;
			}
		};

	my $startit = $typein ->();
	readit();

	my $fullpath;
	state $count = 0;
	sub retour {			
		print BOLD, BLUE, "\nInvalid entry $fullpath: please try again \n\a\n", RESET;
		die "\nToo many futile attempts  ( $!)\n\n" if ( $count++ > 2 );
	}

	my $punch = sub  {
			RE2:
			print "\nLog name, /path/to/logfile or /directory : \n\n   > ";
			# Execute anytime before the <STDIN>.
			# Causes the currently selected handle to be flushed after every print.
			$| = 1;
			my $path = <STDIN>;
			chomp $path;
			print "\n\n";
			unless ( hascontent( $path ) ) {
				print BOLD, BLUE, "No string supplied. Try again!\n", RESET;
				sleep 2;
				goto RE2;
			}
			$fullpath = getlogfilename( $path );
			unless ( $fullpath =~ m{[\.]{1,2}/|[\.~/]?(\W?[A-Za-z0-9]+)+\.?(log)?$}g ) {
				print BOLD, BLUE, "\n...sorry, that looks like an invalid path.\n", RESET;
				&linehere; print "\n";
				sleep 5; print "\nSo try again please.\n\n";
				goto RE2;
			}
			else  {
				my $ret = readit( $fullpath );     print "\nRET : $ret \n";
				unless ( defined $ret ) { &retour; goto RE2; }
				unless ( $ret ) { goto RE2; } 
				getlastpath( $ret );
			}
		};

	my $pathinput = $punch -> ();

	&linehere;
	print "\n\n";

	my $msg = sub {
			no warnings 'numeric';
			use Time::HiRes qw/ gettimeofday /;
			my $time0 = gettimeofday();
			my $st = stat( $fullpath ) or &retour;
			my $details = getlogsearchdrivers( $fullpath, searchconfig( $lang ) );
			my ( $parse ) = map { @$_ } map { $_ } $$details[1];
			if (( $parse =~ m/&&/o ) && ( $configured{FASTSPEED} ))   {
				if ( $$st[7] > 1000000000000000 )  {
					return elasticfilter( $fullpath, $details );
				}
				return additivefilter( $fullpath, $details );
			}
			$$details[1] =~ s/&&/\|/g;
			if (( $$st[7] > 100000 ) && ( $configured{FASTSPEED} ))  {   
				return hugefilter( $fullpath, $details, [$fullpath, [$parse]] );
			}
			else {
				return nofilter( $fullpath, $details );
			}
		};

	use Time::HiRes qw/ gettimeofday /;
	my $time0 = gettimeofday();
	state $result = $msg->();
	my $elapsedtime = gettimeofday() - $time0;
	my $rounded = sprintf( "%.4f", $elapsedtime );
	printf " in $rounded seconds.\n\n";


	my $lastwish = sub  {
			print "\nDo you wish a text file to be stored on Desktop ? (yY/nN) \n\n   > ";
			# Causes the currently selected handle to be flushed after every print.
			$| = 1;
			my $yn = <STDIN>;
			$yn =~ s/\s+$//;
			if ( $yn =~ m/^y/i ) {
				my $filename = "$configured{OUTPUTTO}/LogGrep_$fullpath.txt";
				open( my $fh, '>', $filename ) or die "Could not open file '$filename' $!";
				print $fh map { "$_\n" } @$result;
				close $fh;
			}
		};

	my $finishup = $lastwish ->();
	&linehere;
	print "\nDone.\n\n";

1;

__DATA__


	LOGDIRECTORY : /var/log,

	MONTHAGO : 0,

	OUTPUTTO : /home/fortinbras/Desktop,

	SUPPORT : failures@eclipso.eu,

	FASTSPEED : 1,

	CONFIGFILE : /home/fortinbras/usr/share/perl/




