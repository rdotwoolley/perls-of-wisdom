#!/usr/bin/perl
use Getopt::Long;


options();
palindrome($word);

sub usage
{
	print "pass in a word and we'll check it it's a palindrome!\n";
	exit;
}

sub options
{
	usage () if ( @ARGV < 1 or 
		! GetOptions( 	'help|?'	=> \$help,
						'word=s'	=> \$word)
			or defined $help);
	
}



sub palindrome
{
	print "Word: $word\n";
}
