use Modern::Perl;
use experimental qw( autoderef );
use HTTP::Async;
use HTTP::Request;
use HTML::TreeBuilder;
use URI::Escape qw( uri_escape uri_unescape );
use DBD::Pg;
use List::MoreUtils qw( uniq );
use Time::HiRes qw( time );


my $start_time = time;
my $path_to_file_with_queries = $ARGV[ 0 ];
my $async = HTTP::Async -> new();
my $url = "google.com/search?q=";
my $num_of_requests = 0;
my $num_of_responses = 0;

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

    my @queries = uniq( map { HTTP::Request -> new( $url . uri_escape( $_ ) ) } <$fh> );
    &queue_requests( @queries );

    close( $fh );

    &store_info( &get_info() );

    say "Num of unique queries: " . scalar( @queries );
    say "Num of HTTP requests: " . $num_of_requests;
    say "Num of HTTP responses: " . $num_of_responses;
    say "Execution time (seconds): " . ( $start_time - time );
}

exit 0;


sub queue_requests
{
    $async -> add( shift );
    $num_of_requests ++;
}

sub get_info
{
    my $info = {};
    while ( my $response = $async -> wait_for_next_response() )
    {
        push( $info -> { uri_unescape( $response -> base() ) }, &parse( $response ) );
        $num_of_responses ++;
    }

    return $info;
}

sub parse
{
    my $response = shift;

    my $tree = HTML::TreeBuilder -> new_from_content( $response -> content() );

    my $parsing_first_page = $response -> base() !~ /&start=10$/;

    if( $parsing_first_page )
    {
        my @top_divs = $tree -> look_down( _tag => 'div', class => 'rc' );
        my $rank = 1;
        my @top_info = map { &parse_div( $_, $rank ++ ) } @top_divs;

        # There may be only 9 results on the first page (example query: "obama"). I think, it's due to images bar.
        if( @top_divs < 10 )
        {
            my $second_page_exists = $tree -> look_down( _tag => 'table', id => 'nav' );
            if( $second_page_exists )
            {
                &queue_requests( HTTP::Request -> new( $response -> base() . '&start=10' ) );
            }
        }

        return @top_info;
    }
    else # parsing second page
    {
        my $one_more_div = $tree -> look_down( _tag => 'div', class => 'rc' );
        my $info = &get_info( $one_more_div, 10 );

        return $info;
    }
}

sub parse_div
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

sub store_info
{
    my $info = shift;

    my $dbh = DBI -> connect( "dbi:Pg:dbname=postgres", "", "" );
    for my $query ( keys $info )
    {
        $dbh
            -> prepare( "INSERT INTO queries ( query, rank, url, title, description ) VALUES ( ?, ?, ?, ?, ? ) " )
            -> execute(
                $query,
                $query -> { 'rank' },
                $query -> { 'url' },
                $query -> { 'title' },
                $query -> { 'description' }
            );
    }
}
