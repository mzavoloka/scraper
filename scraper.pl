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
        push( $info -> { uri_unescape( $response -> base() -> as_string() ) }, &parse( $response ) );
        $num_of_responses ++;
    }

    return $info;
}

sub parse
{
    my $response = shift;

    my $tree = HTML::TreeBuilder -> new_from_content( $response -> content() );

    my $parsing_first_page = $response -> base() -> as_string() !~ /&start=10$/;

    if( $parsing_first_page
        and
        my @top_lis = $tree -> look_down( _tag => 'li', class => 'g' ) )
    {
        my $rank = 1;
        my @top_info = map { &parse_li( $_, $rank ++ ) } @top_lis;

        # There may be only 9 results on the first page (example query: "obama"). I think, it's due to images bar.
        if( @top_lis < 10 )
        {
            my $there_is_second_page = $tree -> look_down( _tag => 'table', id => 'nav' );
            if( $there_is_second_page )
            {
                &queue_requests( HTTP::Request -> new( GET => $response -> base() -> as_string() . '&start=10' ) );
            }
        }

        return \@top_info;
    }
    elsif( not $parsing_first_page
           and
           my $one_more_li = $tree -> look_down( _tag => 'li', class => 'g' ) -> [ 0 ] )
    {
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
        my $a = $h3 -> look_down( _tag => 'a' );
        return {
            rank        => $rank,
            url         => $a -> attr( 'href' ),
            title       => $a -> as_text(),
            description => $li -> look_down( _tag => 'span', 'class' => 'st' ) -> as_text()
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
        $dbh
            -> prepare( "INSERT INTO queries ( query, rank, url, title, description, added ) VALUES ( ?, ?, ?, ?, ?, NOW() ) " )
            -> execute(
                $query,
                $query -> { 'rank' },
                $query -> { 'url' },
                $query -> { 'title' },
                $query -> { 'description' }
            );
    }
}
