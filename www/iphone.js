var agent     = navigator.userAgent.toLowerCase();
var is_iphone = ((agent.indexOf('iphone') != -1));

if (is_iphone) { 
    $(document).ready(function(){ 
        $('#header ul').addClass('hide'); 
        $('#header').append('<div class="leftButton" onclick="toggleMenu()">Menu</div>'); 
    });
    function toggleMenu() { 
        $('#header ul').toggleClass('hide'); 
        $('#header .leftButton').toggleClass('pressed'); 
    }
}