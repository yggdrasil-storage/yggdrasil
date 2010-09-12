var agent     = navigator.userAgent.toLowerCase();
var is_iphone = ((agent.indexOf('iphone') != -1));

if (is_iphone) { 
    $(document).ready(function(){ 
        $('#header ul').addClass('hide'); 
        $('#header').append('<div class="rightButton" onclick="toggleStructure()">Tree</div>'); 
        $('#header').append('<div class="leftButton" onclick="toggleMenu()">Menu</div>'); 
	
	$("a#structure").removeAttr( 'onMouseOver' );
	$("a#structure").removeAttr( 'href' );
    });
    function toggleMenu() { 
        $('#header ul').toggleClass('hide');
        $('#header .leftButton').toggleClass('pressed'); 
    }

    function toggleStructure() { 
	if ( $('#entities').length || $('#entitydetails').length ) {
	    $('#entities').remove();
	    $('#entitydetails').remove();
	} else {
	    showStructure();
	}
    }
}
