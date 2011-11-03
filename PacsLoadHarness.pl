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

# Minor bit of preparation here. Create a directory in the cwd that uses the testrun name arg
# -------------------------------------------------------------------------------------------
mkdir "$testResultsPath/$testRunName";
$testResultsPath = "$testResultsPath/$testRunName";

# Open a summary File
# ---------------------------------------------------
open(summary,  ">> $testResultsPath/Summary-$testRunName.txt");

# Print out the column headers in the summary file
# -------------------------------------------------- 
print summary "Object,AvgTime,MB/Sec,\n";



startSAR($users);
launchinator($users);
postProcessinator($users);
summarize($users);
	


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
	system("ssh root\@$remoteClient '/root/rwoolley/PacsLoadTest-Albania/pacs/bin/PacsLoadTest /root/rwoolley/PacsLoadTest-Albania/pacs/bin/pacsloadtest_config.xml 2> ~/testingResults`date +%Y-%m-%d`/$testRunName/$testRunName-PacsLoadTest.txt '");
	
}


# This is the post processing function.  It will parse out all the details
# from the SAR data file and the nvidia data file and turn it into CSV
# so it can be dropped into Excel.
#------------------------------------------------------------------------
sub postProcessinator
{
	$numUsers = $_[0];
	
	# Get the PacsLoadtest results file from the remote client and put in directory on test hardware
	# -------------------------------------------------------------------------------------
	system ("scp root\@$remoteClient:testingResults`date +%Y-%m-%d`/$testRunName/$testRunName-PacsLoadTest.txt $testResultsPath");

	# post process the SAR
	# ---------------------
	
	# Networking Details
	# ---------------------
	system("sadf -d -H $testResultsPath/performance_pacsloadtest-`date +%Y-%m-%d`.file -- -n DEV | grep eth0 >$testResultsPath/network_pacsloadtest-`date +%Y-%m-%d_%H-%M`.csv");

	# CPU
	# ----------------------
	system("sadf -d -H $testResultsPath/performance_pacsloadtest-`date +%Y-%m-%d`.file -- -P ALL > $testResultsPath/cpu_pacsloadtest-`date +%Y-%m-%d_%H-%M`.csv");
	
	# Memory
	# ----------------------
	system("sadf -d -H $testResultsPath/performance_pacsloadtest-`date +%Y-%m-%d`.file -- -r > $testResultsPath/memory_pacsloadtest-`date +%Y-%m-%d_%H-%M`.csv");
	
	# IO
	# ----------------------
	system("sadf -d -H $testResultsPath/performance_pacsloadtest-`date +%Y-%m-%d`.file -- -b > $testResultsPath/disk_io_pacsloadtest-`date +%Y-%m-%d_%H-%M`.csv");
	

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
sub startSAR
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
	system("sar -bdr -n DEV -P ALL -o $testResultsPath/performance_pacsloadtest-`date +%Y-%m-%d`.file 10 $testLength >/dev/null 2>&1 &");
	if ( $? == -1 )
	{
  		print "sar command failed: $!\n";
	}
	else
	{
  		printf "sar launched! returned value: %d", $? >> 8;
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
	my @studyTime=();
	my @studyMBs=();
	my @tnailTime=();
	my @tnailMBs=();
	my @series=();
	my @studyList=();
	my @seriesList=();
	my @srList=();
	my $total=0;
	$numUsers=$_[0];
		




	
	# Process StudyLoad Time Avg and BW average 
	# ---------------------------------------------------
	$output = `cat $testResultsPath/$testRunName-PacsLoadTest.txt | grep "Loading study took"`;
 	@firstSplit = split /\n/, $output;
	foreach (@firstSplit)
	{
        	@temp = split / /, $_;
                push(@StudyTime, @temp[12]);
		push(@StudyMBs, @temp[14]);
	}
	
	# Average Study Loadtime	
	foreach (@StudyTime)
	{
        	$total= $total+ $_;
	}	
	$average = $total / @StudyTime;
	print summary "Study,$average,";

	# Average Study MBs
	$average = 0;
	$total = 0;
	foreach (@StudyMBs)
	{
        	$total= $total+ $_;
	}	
	$average = $total / @StudyMBs;
	print summary "$average";
	print summary "\n";

	# Process tnail time and BW averages
	# ---------------------------------------------------
	$average = 0;
	$total = 0;
	$output=0;
	@firstSplit = ();
	@temp = (); 
	
	$output = `cat $testResultsPath/$testRunName-PacsLoadTest.txt | grep "Loading thumbnail took"`;
        @firstSplit = split /\n/, $output;                                          
        foreach (@firstSplit)                                                       
        {
                @temp = split / /, $_;                                              
                push(@tnailTime, @temp[12]);
                push(@tnailMBs, @temp[14]);                                         
        }                                                                           
                
        # Average tnail Loadtime                                                    
        foreach (@tnailTime)
        {
                $total= $total+ $_;                                                 
        }                                                                           
        $average = $total / @tnailTime;
        print summary "tnail,$average,";
        
        # Average tnail MBs                                                         
        $average = 0;                                                               
        $total = 0; 
        foreach (@tnailMBs)                                                         
        {                                                                           
                $total= $total+ $_;                                                 
        }       
        $average = $total / @tnailMBs;                                              
        print summary "$average";                                                   
        print summary "\n";  

}	
	
