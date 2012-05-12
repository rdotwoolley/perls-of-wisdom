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
	my $testword 	= $_[0];
	my $length	= length($testword);
	

	# Start with the longest word and go down
	# ---------------------------------------
OUTER:	for ($i = 0; $i < $length; $i++)
		{
			for ($j = $length; $j > 1; $j--)
			{
				$subword 	= substr $testword, $i, $j;
				$revsubword = reverse scalar $subword;
				if ($subword eq $revsubword)
				{
					print "Booyah, we have palindrome: $subword \| $revsubword\n";
					last OUTER;
				}
			}
		}
	
}
