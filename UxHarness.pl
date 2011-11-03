#!/usr/bin/perl



#----------------------------------------------------------
# TESTICLES The Grecko-Roman god of tests and monitoring
# 
# This script is the harness we constructed to run 
# a predefined testscript and monitor the CPU, RAM, IO,
# GPU, and network bandwidth.  It's a crazy combo of 
# ---------------------------------------------------------
use Getopt::Long;
use Cwd;

# GLOBALS
my $testRunName;
my $hostname;
my $date;
my $remoteClient;
my $testResultsPath = getcwd;
my $testDuration = 0;

options();
#verify();
#printGlobals();

# Here, for each testRun, repeat it with 4,8,12,16,20,24,28,32,36,40 users.
# For that to work you have to have matching script files setup.
# Those files can be found here:
#---------------------------------------------------------------------------
@iterations=("4","8","12","16","20","24","28","32","36","40");

# Minor bit of preparation here. Create a directory in the cwd that uses the testrun name arg
# -------------------------------------------------------------------------------------------
mkdir "$testResultsPath/$testRunName";
$testResultsPath = "$testResultsPath/$testRunName";

# Open a summary File
# ---------------------------------------------------
open(summary,  ">> $testResultsPath/Summary-$testRunName.txt");
print summary "NumUsers,FPSavg,CPUavg,GPUavg,BWavg\n";



foreach(@iterations)
{
	$users=$_;
	startSARandSMI($users);
	launchinator($users);
	postProcessinator($users);
	summarize($users);
	
}

#startSARandSMI(20);
#launchinator(20);
#postProcessinator(20);
#summarize(20);

# Close the file
# ----------------------------------------------------------
close (summary);

# This is the remote test launcher.  For other folks use this function
# as the launch point for whatever drone, client simulator etc, you're using
# -------------------------------------------------------------------------
sub launchinator
	{
	$numUsers=$_[0];
	# create a directory on the remoteClient to put the results in
	# ------------------------------------------------------------
	system("ssh root\@$remoteClient mkdir -p ~/testingResults`date +%Y-%m-%d`/$testRunName");
	
	# Launch the unit test
	# This system call blocks the rest of the script, this is why
	# the monitors must be init'd first
	# ------------------------------------------------------------
	system("ssh root\@$remoteClient '/root/PerfTool/CSI.PerformanceTest.UnitTests /root/PerfTool/test-script-$numUsers.xml > ~/testingResults`date +%Y-%m-%d`/$testRunName/$testRunName-numUsers-$numUsers-UxResults.txt '");
	
}


# This is the post processing function.  It will parse out all the details
# from the SAR data file and the nvidia data file and turn it into CSV
# so it can be dropped into Excel.
#------------------------------------------------------------------------
sub postProcessinator
{
	$numUsers = $_[0];
	# Kill the nvidia SMI
	# -------------------------------
	processKillah("nvidia-smi");
	
	# Get the FPS results file from the remote client and put in directory on test hardware
	# -------------------------------------------------------------------------------------
	system ("scp root\@$remoteClient:testingResults`date +%Y-%m-%d`/$testRunName/$testRunName-numUsers-$numUsers-UxResults.txt $testResultsPath");

	# post process the SAR
	# ---------------------
	
	# Networking Details
	# ---------------------
	system("sadf -d -H $testResultsPath/performance_numUsers-$numUsers-`date +%Y-%m-%d`.file -- -n DEV | grep eth0 >$testResultsPath/network_numUsers-$numUsers-`date +%Y-%m-%d_%H-%M`.csv");

	# CPU
	# ----------------------
	system("sadf -d -H $testResultsPath/performance_numUsers-$numUsers-`date +%Y-%m-%d`.file -- -P ALL > $testResultsPath/cpu_numUsers-$numUsers-`date +%Y-%m-%d_%H-%M`.csv");
	
	# Memory
	# ----------------------
	system("sadf -d -H $testResultsPath/performance_numUsers-$numUsers-`date +%Y-%m-%d`.file -- -r > $testResultsPath/memory_numUsers-$numUsers-`date +%Y-%m-%d_%H-%M`.csv");
	
	# IO
	# ----------------------
	system("sadf -d -H $testResultsPath/performance_numUsers-$numUsers-`date +%Y-%m-%d`.file -- -b > $testResultsPath/disk_io_numUsers-$numUsers-`date +%Y-%m-%d_%H-%M`.csv");
	
	# post process the SMI
	# ------------------------
	system("cat $testResultsPath/nvidia_data_numUsers-$numUsers-`date +%Y-%m-%d`.txt | grep \"Timestamp\\|GPU\" --exclude \"\n\" | awk \'/Timestamp/{print $6} /GPU/{print $NF}\' > $testResultsPath/GPU_Utility_numUsers-$numUsers-`date +%Y-%m-%d`.txt");

	# Post process the FPS results
	# -----------------------------
	system("cat $testResultsPath/$testRunName-numUsers-$numUsers-UxResults.txt | grep fps > $testResultsPath/FPS-numUsers-$numUsers-`date +%Y-%m-%d`.txt");
		

}

# This function will take in a string argument then use that as a filter
# on a process listing command to isolate a pid then kill -2 the pid
# -------------------------------------------------------------------
sub processKillah
{
	$processName = $_[0];
	$processList = `ps -ef | grep $processName`; 
	@processArray = split /\s+/, $processList;
	print "processList: $processList\n";
	if ($processName eq $processArray[7])
	{
		print "Killing: $processArray[7] PID: $processArray[1]\n";
		$result = `kill -2 $processArray[1]`;
	}
	else
	{
		print "No $processName processes to kill\n";
	}
	

}


# This function will start sar (part of the sysstat library as well as the nvidia SMI
# ARGS: Interval (how long to run sar and smi in collection mode
#------------------------------------------------------------------------------------
sub startSARandSMI
{
	$testLength = 14;
	$numUsers = $_[0];
	
	# Minor bit of preparation here. Create a directory in the cwd that uses the testrun name arg
	# -------------------------------------------------------------------------------------------
	#mkdir "$testResultsPath/$testRunName";
	#$testResultsPath = "$testResultsPath/$testRunName";

	# Ok, strap in and get ready to rip it. Our SAR command looks like this:
	# sar -bdr -n DEV -P ALL -o performance_`date +%Y-%m-%d`.file 10 $testLength
	# -b  Reports the I/O and transfer rate statistics.
	# -d  Reports the activity for each block device.
	# -r   Reports the memory utilization statistics in kilobytes.
	# -n  DEV Reports all network device statistics.
	# -P  Report per-processor statistics for the specified processor or processors. 
	#     Specifying the ALL keyword reports statistics for each individual processor, and globally for all processors. 
	#     Note that processor 0 is the first processor.
	# -o  Is the output location of the output file.
	#  10 $testLength  Is the interval in seconds and the number of intervals respectively.
	#  ">/dev/null 2>&1 &" is added to the end of the command to supress the output and run bg 
	#---------------------------------------------------------------------------------------
	system("sar -bdr -n DEV -P ALL -o $testResultsPath/performance_numUsers-$numUsers-`date +%Y-%m-%d`.file 10 $testLength >/dev/null 2>&1 &");
	if ( $? == -1 )
	{
  		print "sar command failed: $!\n";
	}
	else
	{
  		printf "sar launched! returned value: %d", $? >> 8;
	}

	# nvidia-smi initialization
	# This setup is a bit ugly, the SMI doesn't have a timer we'll have to: 
	# 	start smi
	#	fire up the testcast
	# 	sleep the perl script for the length of the test
	# 	wakeup and kill -2 the pid
	# 	move onto the post processing of the datafiles.
	# SMI Command:
	#  nvidia-smi -l -i 10 -d > nvidia_data_`date +%Y-%m-%d`.txt
	# ------------------------------------------------------------------------	
	system("nvidia-smi -l -i 10 -d > $testResultsPath/nvidia_data_numUsers-$numUsers-`date +%Y-%m-%d`.txt &");
	if ( $? == -1 )
	{
  		print "SMI command failed: $!\n";
	}
	else
	{
  		printf "\nSMI Launched! Returned Value:  %d\n", $? >> 8;
	}
	
}



sub verify
{
	# Check that you have sysstat v10.0.2 or greater installed
	$sysstat = `/usr/local/bin/sar -V`;
	@splitter = split(/ /,$sysstat);
	if ( $splitter[2] >= 10.0.2)
	{
		print "Acceptable version of sysstat library installed\n";	
	}
	else
	{ 
		print "Newer version of sysstat library needed. Check: http://sebastien.godard.pagesperso-orange.fr/";
	}


}


#-- prints usage if no command line parameters are passed or there is an unknown
#   parameter or help option is passed
sub options
{
	my $missingArg = 0; 

	usage()  if ( @ARGV < 1 or 
    	  ! GetOptions(	'help|?' 	 => \$help,   
			'testRunName=s'  => \$testRunName,
			'remoteClient=s' => \$remoteClient)
		  or defined $help);
	#print "help=$help\n";
	
}



sub printGlobals
{
	print "\ntestRunName=$testRunName\n";
	print "hostname=$hostname\n";
	print "remoteClient=$remoteClient\n";
	print "testResultsPath: $testResultsPath\n";
}



sub usage
{
	print "\n\nUsage: testicles [--remoteClient HOSTNAME|IP] [--testRunName NAME] [--help|-?]\n";
 	print "Ensure that you have ssh keys setup between the test hardware and the remoteClient.\n Check this link: http://community.spiceworks.com/education/projects/Passwordless_SSH_Using_Shared_Keys\n";	
	exit;	
}


# This is a very custom script for the output generated by sar, nvidia-smi, and our custom tool
# ---------------------------------------------------------------------------
sub summarize
{
	my @fps=();
	my @CPU=();
	my @NET=();
	my @GPU=();
	my $total=0;
	$numUsers=$_[0];
		

	# Post the numUsers for this iteration
	print summary "$numUsers,";
	
	# Process FPS Avg 
	# ---------------------------------------------------
	$output = `cat $testResultsPath/$testRunName-numUsers-$numUsers*UxResults.txt | grep "average fps:"`;
	@firstSplit = split /\n/, $output;
	foreach (@firstSplit)
	{
        	@temp = split / /, $_;
        	if (@temp[2] ne "nan")
        	{	
                	push(@fps, @temp[2]);
        	}
	}

	foreach (@fps)
	{
        	$total= $total+ $_;
	}	

	$average = $total / @fps;

	print summary "$average,";

	# Process CPU Avg
	# ---------------------------------------------------
	$average = 0;
	$total = 0;
	$output=0;
	@firstSplit = ();
	@temp = (); 
	$output = `cat $testResultsPath/cpu_numUsers-$numUsers*csv`;
 	@firstSplit = split /\n/, $output;
	foreach (@firstSplit)
	{
		@temp = split /;/, $_;
		push(@CPU, @temp[6]);
	}	
	foreach (@CPU)
	{
		$total=$total + $_;
	}
	$average = $total / @CPU;
	print summary "$average,";

	# Process GPU Avg
	# ---------------------------------------------------
	$average = 0;
	$total = 0;
	$output=0;
	@firstSplit = ();
	@temp = (); 
	$output = `cat $testResultsPath/nvidia_data_numUsers-$numUsers*.txt | grep -w "GPU" | grep %`;
 	@firstSplit = split /\n/, $output;
	foreach (@firstSplit)
	{
		@temp = split /\s+/, $_;
		push(@GPU, @temp[3]);
	}	
	foreach (@GPU)
	{
		$total=$total + $_;
	}
	$average = $total / @GPU;
	print summary "$average,";

	# Process BW Avg
	# ---------------------------------------------------
	$average = 0;
	$total = 0;
	$output=0;
	@firstSplit = ();
	@temp = (); 
	$output = `cat $testResultsPath/$testRunName-numUsers-$numUsers*UxResults.txt | grep "avg bandwidth:"`;
	@firstSplit = split /\n/, $output;
	foreach (@firstSplit)
	{
        	@temp = split / /, $_;
               	push(@NET, @temp[2]);
	}
	foreach (@NET)
	{
        	$total= $total+ $_;
	}
	$average=$total / @NET;
	print summary "$average\n";
		

}	
	
