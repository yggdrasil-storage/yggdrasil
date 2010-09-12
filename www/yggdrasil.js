function flipper(one, two) {
    var id_one = "#" + one;
    var id_two = "#" + two;

    var one = $(id_one).css("display");
    var two = $(id_two).css("display");
    
    $(id_one).css( "display", one == '' || one == 'block' ? 'none' : 'block' );
    $(id_two).css( "display", two == '' || two == 'block' ? 'none' : 'block' );
}

function showStructure() {
    var entities;
    var query = 'entities';
    var data;


    if ( $('ul.entitylist').length > 0 ) {
	// We havea previous entry in the code, remove it and start
	// over.  Timer?
	$('#entitydetails').remove();
	$('ul.entitylist').remove();
    }

    $("a#structure").attr ('href', '#');

    if ( ! $('#entities').length ) {
	$('#container').append('<div id="entities" title="Click to close navigator">' +
			       '<img src="images/close.png" title="Close" id="closer" heigh="10" width="13" /><h3>Entities</h3></div>'); 
    }

    $('#entities').show( 100 );

    var cb = function(data) {
	process( query, data );	
    }

    var hideme = function() {
	$('#entitydetails').remove();
	$('#entities').hide( 300 );
    }

    $.post( "ajax/foo.cgi", { mode: query }, cb, "json" );

    $('#entities h3').click( hideme );
    $('#closer').click( hideme );
    // $('#entities h3').mouseover( showclose );
    // $('#entities h3').mouseout( shownormal );

}

function showclose() {  
    $('#entities h3').html( 'Close' );
}

function shownormal() {  
    $('#entities h3').html( 'Entities' );
}

function process( q, d ) {
    var query = q;
    var input = d;

    if (query == 'entities') {
	var list = document.createElement( 'ul' );
	list.className = 'entitylist';
	for (var i=0; i<input.length; i++) {
	    var newPara = document.createElement( 'li' );
	    var newParaText = document.createTextNode( input[i] );
	    newPara.setAttribute( 'title', "Click to expand, double click to display" );
	    newPara.appendChild( newParaText );
	    list.appendChild( newPara );
	}
	$('#entities').append( list );
    }
    $('#entities ul li').click( doentity );
    $('#entities ul li').dblclick( gotoEntity );
}

function gotoEntity() {
    var entity = this.innerHTML;
    
    window.location = '?entity=' + entity;
}

function doentity() {
    var entity = this.innerHTML;

    var entitycb = function(data) {
	processEntity( entity, data );	
    }

    $.post( "ajax/foo.cgi", { entity: entity }, entitycb, "json" );
}

function processEntity( e, data ) {
    var input = data;
    
    var instances  = data[0];
    var properties = data[1];

    var ewidth = $('#entities').width();

    $('#entitydetails').remove();
    $('#container').append('<div id="entitydetails"></div>' );

    $('#entitydetails').css( 'position', 'absolute' );
    $('#entitydetails').css( 'top', '50px' );
    $('#entitydetails').css( 'left', ewidth + 50 );

    $('#entitydetails').show( 100 );

    if (! data[0].length && ! data[1].length ) {
	$('#entitydetails').append( '(empty)' );
	return;
    }

    //    for (var type=0; type<input.length; type++) {
    for (var type=0; type<1; type++) {
 	if (data[type].length) {
	    var list = document.createElement( 'ul' );
 	    if (type == 0) {
 		list.className = 'instancelist';
		$('#entitydetails').append('<h4>Instances</h4>' );
 	    } else {
 		list.className = 'propertylist';
		$('#entitydetails').append('<h4>Properties</h4>' );
 	    }	    
	    
 	    for (var i=0; i<data[type].length; i++) {
 		var newPara = document.createElement( 'li' );
 		var newParaText = document.createTextNode( data[type][i] );
		newPara.setAttribute( 'title', "Click to display" );	    
 		newPara.appendChild( newParaText );
 		list.appendChild( newPara );
 	    }
	    $('#entitydetails').append( list );
 	}
     }

    $('#entitydetails ul li').click( function() { doInstanceOrProperty( e, this ) } );
}

function doInstanceOrProperty( e, li ) {
    var entity = e;
    var label  = li.innerHTML;

    window.location = '?entity=' + entity + ';instance=' + label;


    // window.location
    
}