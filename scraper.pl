use Modern::Perl;
use HTTP::Async;
use HTTP::Request;
use HTML::TreeBuilder;


my $path_to_file_with_queries = $ARGV[ 0 ];
my $async = HTTP::Async -> new();
my $link = "google.com/search?q=";

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

    $async -> add( map { HTTP::Request -> new( $link . $_ ) } <$fh> );

    close( $fh );

    while ( my $response = $async -> wait_for_next_response() )
    {
        my $tree = HTML::TreeBuilder -> new_from_content( $response -> content() );
        my @top10 = $tree -> look_down( 'class', 'rc' );
    }

}
