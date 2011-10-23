#!/usr/bin/perl

use Getopt::Long;
use Cwd;

# GLOBALS
my $ResmdHost;
my $PacsHost;
my $PacsDcmPort;
my $ListenerDcmPort;
my $PacsAETitle;
my $ListenerAETitle;
my $missionName;
my $help;
my $cwd=getcwd;


options();
printGlobals();

$workDir="$cwd/$missionName";
mkdir "$workDir";

dcmqrXSL();
scriptBuilder();

sub printGlobals
{
	print "Listenerdcmport: $ListenerDcmPort\n";
	print "ListenerAEtitel: $ListenerAETitle\n";
	print "PacsDcmPort: $PacsDcmPort\n";
	print "Pacshost: $PacsHost\n";
	print "pacsAEtitel: $PacsAETitle\n";
	print "resmdhost: $ResmdHost\n";
	print "MissionName: $missionName\n";
	print "CWD: $cwd\n";
}

#-- prints usage if no command line parameters are passed or there is an unknown
#   parameter or help option is passed
sub options
{
	my $missingArg = 0; 

	usage()  if ( @ARGV < 1 or 
    	  ! GetOptions(	'help|?' 	 => \$help,   
			'ResmdHost=s'  => \$ResmdHost,
			'PacsHost=s'  => \$PacsHost,
			'PacsDcmPort=s'  => \$PacsDcmPort,
			'PacsAETitle=s'  => \$PacsAETitle,
			'ListenerAETitle=s'  => \$ListenerAETitle,
			'ListenerDcmPort=s'  => \$ListenerDcmPort,
			'missionName=s'  => \$missionName)
		  or defined $help);
	#print "help=$help\n";

}


sub dcmqrXSL
{
	open(dcmqrXSLfile, ">> $workDir/dcmqr.xsl");
	print dcmqrXSLfile "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n";	
	print dcmqrXSLfile "<xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\"> \n";
	print dcmqrXSLfile "<xsl:template match=\"/\"> \n";
  	print dcmqrXSLfile "<xsl:for-each select=\"StudyList/Study\"> \n";
    print dcmqrXSLfile "mkdir -p \"$workDir/<xsl:value-of select=\"PatientName\"/>\" \n";     
    print dcmqrXSLfile "dcmqr -L $ListenerAETitle:$ListenerDcmPort $PacsAETitle\@$PacsHost:$PacsDcmPort -cmove $ListenerAETitle  -qPatientName=\"<xsl:value-of select=\"PatientName\"/>\" -cstore <xsl:value-of select=\"ModalitiesInStudy\"/> -cstoredest \"$workDir/<xsl:value-of select=\"PatientName\"/>\" \n";     
	print dcmqrXSLfile "</xsl:for-each> \n";
	print dcmqrXSLfile "</xsl:template> \n";
	print dcmqrXSLfile "</xsl:stylesheet> \n";

close (dcmqrXSLfile);
}

#TODO put the user and passwd into the args
sub scriptBuilder
{
	system ("curl http://$ResmdHost:8080/pureweb/dicom/studies --user admin:admin >>  $workDir/data.xml");
	system ("xsltproc $workDir/dcmqr.xsl $workDir/data.xml >> $workDir/dcmqr.sh");
}



sub usage
{
	print "\n\nUsage: pacsraptor [--ResmdHost HOSTNAME|IP] [--PacsHost HOSTNAME|IP] [--PacsDcmPort #####] [--PacsAETitle aetitle] [--ListenerAETitle AETitle ][--ListenerDcmPort #####][--missionName NAME]  [--help|-?]\n";
	exit;	
}


