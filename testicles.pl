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
#startSARandSMI(3);
launchinator();


# This is the remote test launcher.  For other folks use this function
# as the launch point for whatever drone, client simulator etc, you're using
# -------------------------------------------------------------------------
sub launchinator
{
	
	# create a directory on the remoteClient to put the results in
	# ------------------------------------------------------------
	system("ssh root\@$remoteClient mkdir -p ~/testingResults`date +%Y-%m-%d`/$testRunName");
	# Launch the unit test
	# ------------------------------------------------------------
	system("ssh root\@$remoteClient \"/root/PerfTool/CSI.PerformanceTest.UnitTests /root/PerfTool/test-script.xml 2> /dev/null > ~/testingResults`date +%Y-%m-%d`/$testRunName/$testRunNameResults.txt &\"");
	
}


# This is the post processing function.  It will parse out all the details
# from the SAR data file and the nvidia data file and turn it into CSV
# so it can be dropped into Excel.
#------------------------------------------------------------------------
sub postProcessinator
{
	# Sleep for the test duration + 5 seconds
	# ----------------------------------------
	print "\n Sleeping the perl script while the test runs for $testDuration seconds.\n");
	sleep($testDuration + 5);

	# Kill the nvidia SMI
	# -------------------------------
	#processKillah("nvidia-smi");
	
	# Get the FPS results file from the remote client and put in directory on test hardware
	# -------------------------------------------------------------------------------------
	system ("scp root\@$remoteClient:testingResults`date +%Y-%m-%d`/$testRunName/$testRunNameResults.txt $testResultsPath");

	# post process the SAR
	# ---------------------
	
	# Networking Details
	# ---------------------
	system("sadf -d -H $testResultsPath/performance_`date +%Y-%m-%d_%H-%M`.file -- -n DEV | grep eth0 >network_`date +%Y-%m-%d_%H-%M`.csv");

	# CPU
	# ----------------------
	system("sadf -d -H $testResultsPath/performance_`date +%Y-%m-%d_%H-%M`.file -- -P ALL > cpu_`date +%Y-%m-%d_%H-%M`.csv");
	
	# Memory
	# ----------------------
	system("sadf -d -H $testResultsPath/performance_`date +%Y-%m-%d_%H-%M`.file -- -r > memory_`date +%Y-%m-%d_%H-%M`.csv");
	
	# IO
	# ----------------------
	system("sadf -d -H $testResultsPath/performance_`date +%Y-%m-%d_%H-%M`.file -- -b > disk_io_`date +%Y-%m-%d_%H-%M`.csv");
	
	# post process the SMI
	# ------------------------
	system("cat $testResultsPath/nvidia_data_`date +%Y-%m-%d`.txt | grep "Timestamp\|GPU" --exclude "\n" | awk '/Timestamp/{print $6} /GPU/{print $NF}' > GPU_Utility`date +%Y-%m-%d`.txt");

	# Post process the FPS results
	# -----------------------------
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
	$testLength = $_[0];
	
	# Minor bit of preparation here. Create a directory in the cwd that uses the testrun name arg
	# -------------------------------------------------------------------------------------------
	mkdir "$testResultsPath/$testRunName";
	$testResultsPath = "$testResultsPath/$testRunName";

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
	system("sar -bdr -n DEV -P ALL -o $testResultsPath/performance_`date +%Y-%m-%d`.file 10 $testLength >/dev/null 2>&1 &");
	if ( $? == -1 )
	{
  		print "sar command failed: $!\n";
	}
	else
	{
  		printf "sar command exited with value %d", $? >> 8;
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
	system("nvidia-smi -l -i 10 -d > $testResultsPath/nvidia_data_`date +%Y-%m-%d`.txt &");
	if ( $? == -1 )
	{
  		print "SMI command failed: $!\n";
	}
	else
	{
  		printf "\nSMI LAUNCHED! %d\n", $? >> 8;
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
			'remoteClient=s' => \$remoteClient,
			'testDuration=s' => \$testDuration)
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


	
