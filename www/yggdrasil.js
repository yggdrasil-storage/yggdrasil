function flipper(one, two) {
    var id_one = "#" + one;
    var id_two = "#" + two;

    var one = $(id_one).css("display");
    var two = $(id_two).css("display");
    
    $(id_one).css( "display", one == '' || one == 'block' ? 'none' : 'block' );
    $(id_two).css( "display", two == '' || two == 'block' ? 'none' : 'block' );
}


function doSecret() {
    var cb = function(data) {
	$("#secret").html( data["happy"] + ". " + data["joy"] );
    }

    $.post( "ajax/foo.cgi", {}, cb, "json" );
}