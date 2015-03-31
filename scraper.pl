use Modern::Perl;

my $path_to_file_with_queries = $ARGV[ 0 ];

if ( not $path_to_file_with_queries )
{
    say "Please, pass the path to file with queries as command line argument. Example: ";
    say "perl scraper.pl /path/to/file";
}
elsif ( not -T $path_to_file_with_queries )
{
    say "File with queries should be an ASCII or UTF-8 text file.";
}
else
{
    open( my $fh, '<', $path_to_file_with_queries )
        or die "Couldn't open file $path_to_file_with_queries: $!";
    while ( my $query = <$fh> )
    {
        say $query;
        #&process_query();
    }
    close( $fh );
}


use LWP::UserAgent;
my $link = "google.com/search?q=";
sub process_query
{
    my $query = shift;

    my $ua = LWP::UserAgent -> new();
    $ua -> get( $link . $query );
    $ua -> response();
}
