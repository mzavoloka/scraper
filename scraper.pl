use Modern::Perl;
use experimental qw( autoderef );
use HTTP::Async;
use HTTP::Request;
use HTML::TreeBuilder;
use URI::Escape qw( uri_escape uri_unescape );
use DBI;
use List::MoreUtils qw( uniq );
use Time::HiRes qw( time );


my $start_time = time;
my $path_to_file_with_queries = $ARGV[ 0 ];
my $async = HTTP::Async -> new();
my $url = "http://google.com/search?q=";
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
    
    my @queries = uniq( map {
            $_ =~ s/\R//g;
            HTTP::Request -> new( GET => $url . uri_escape( $_ ) );
        } <$fh> );
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
    $async -> add( @_ );
    $num_of_requests += scalar @_;
}

sub get_info
{
    my $info = {};
    while ( my $response = $async -> wait_for_next_response() )
    {
        my $url = uri_unescape( $response -> base() -> as_string() );
        $info -> { $url } = [] unless ( $info -> { $url } );
        push( $info -> { $url }, &parse( $response ) );
        $num_of_responses ++;
    }

    return $info;
}

sub parse
{
    my $response = shift;

    my $tree = HTML::TreeBuilder -> new_from_content( $response -> content() );

    my $parsing_first_page = $response -> base() -> query() !~ /&start=10$/;

    my @li_tags = $tree -> look_down( _tag => 'li', class => 'g' );

    if( $response -> base() -> as_string() !~ /\?|&q=/ )
    {
        say "Google weirdly redirected";
    }
    elsif( $parsing_first_page )
    {
        my $rank = 1;
        my @top_info = map { &parse_li( $_, $rank ++ ) } @li_tags;

        # There may be only 9 results on the first page. I think, it's due to images bar.
        if( @li_tags < 10 )
        {
            my $nav_table = $tree -> look_down( _tag => 'table', id => 'nav' );
            my $there_is_second_page = $nav_table ? $nav_table -> as_text() : 0;
            if( $there_is_second_page )
            {
                &queue_requests( HTTP::Request -> new( GET => $response -> base() -> as_string() . '&start=10' ) );
            }
        }

        return \@top_info;
    }
    elsif( not $parsing_first_page )
    {
        my $one_more_li = $li_tags[0];
        my $info = &parse_li( $one_more_li, 10 );

        return $info;
    }
    else
    {
        die 'Unexpected behaviour';
    }
}

sub parse_li
{
    my ( $li, $rank ) = @_;

    if( my $h3 = $li -> look_down( _tag => 'h3', 'class' => 'r' ) )
    {
        my $descr = $li -> look_down( _tag => 'span', 'class' => 'st' );
        my $a = $h3 -> look_down( _tag => 'a' );
        return {
            rank        => $rank,
            url         => $a -> attr( 'href' ),
            title       => $a -> as_text(),
            description => $descr ? $descr -> as_text() : ''
        };
    }
    else
    {
        die 'Unexpected behaviour';
    }
}

sub store_info
{
    my $info = shift;

    my $dbh = DBI -> connect( "dbi:Pg:", '', '', { AutoCommit => 0, RaiseError => 1 } )
        or die $DBI::errstr;

    for my $query ( keys $info )
    {
        my $existing_query_id = $dbh -> selectrow_hashref( "SELECT FROM queries WHERE query = ?", $query ) -> { 'id' };
        if( not $existing_query_id )
        {
            $dbh -> prepare( "INSERT INTO queries ( query ) VALUES ?" ) -> execute( $query );
            $existing_query_id = $dbh -> last_insert_id();
        }

        for my $position ( $info -> { $query } )
        {
            $dbh
                -> prepare( "INSERT INTO info ( query, rank, url, title, description, added ) VALUES ( ?, ?, ?, ?, ?, NOW() ) " )
                -> execute(
                    $existing_query_id,
                    $position -> { 'rank' },
                    $position -> { 'url' },
                    $position -> { 'title' },
                    $position -> { 'description' }
                );
        }
    }
}
