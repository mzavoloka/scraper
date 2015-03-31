use Modern::Perl;
use HTTP::Async;
use HTTP::Request;
use HTML::TreeBuilder;
use URI::Escape qw( uri_escape );


my $path_to_file_with_queries = $ARGV[ 0 ];
my $async = HTTP::Async -> new();
my $url = "google.com/search?q=";

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

    $async -> add( map { HTTP::Request -> new( $url . uri_escape( $_ ) ) } <$fh> );

    close( $fh );

    while ( my $response = $async -> wait_for_next_response() )
    {
        &parse( $response );
    }

}

sub parse
{
    my $response = shift;

    my $tree = HTML::TreeBuilder -> new_from_content( $response -> content() );

    my $parsing_first_page = response -> base() !~ /&start=10$/;

    if( $parsing_first_page )
    {
        my @top10_divs = $tree -> look_down( _tag => 'div', class => 'rc' );
        my $rank = 1;
        my @top10_info = map { &get_info( $_, $rank ++ ) } @top10_divs;

        # There may be only 9 results on the first page (example query: "obama"). I think, it's due to images bar.
        if( @top10_divs < 10 )
        {
            my $second_page_exists = $tree -> look_down( _tag => 'table', id => 'nav' );
            if( $second_page_exists )
            {
                $async -> add( HTTP::Request -> new( $response -> base() . '&start=10' ) );
            }
        }
    }
    else # parsing second page
    {
        my $one_more_div = $tree -> look_down( _tag => 'div', class => 'rc' );
    }
}

sub get_info
{
    my ( $div, $rank ) = @_;
    my $a = $div -> look_down( _tag => 'h3', 'class' => 'r' ) -> look_down( _tag => 'a' );

    return {
        rank        => $rank,
        url         => $a -> attr( 'href' ),
        title       => $a -> as_text(),
        description => $div -> look_down( _tag => 'span', 'class' => 'st' ) -> as_text()
    };
}
