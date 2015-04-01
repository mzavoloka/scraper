// Example response
// {"p1": "val1", "p2": "val2", "p3":"val3", "p4":"val4"}

$( document ).ready( function() {

    $.ajax( '/update_stats' )
        .done( function( response ) {
            var res = $.parseJSON( response );

            for ( var key in res )
            {
              $( '#' + key ).html( res[ key ] );
            }
        } )
        .fail( function( response ) {
            console.log( response.message );
        } );          

} );
