function getstyle(ident) {
  var elem;
  if( document.getElementById ) // this is the way the standards work
    elem = document.getElementById( ident );
  else if( document.all ) // this is the way old msie versions work
      elem = document.all[ident];
  else if( document.layers ) // this is the way nn4 works
    elem = document.layers[ident];
  return elem.style;
}

function flipper(one, two) {
    var ones, twos;

    ones = getstyle(one);
    twos = getstyle(two);

    ones.display = (ones.display==''||ones.display=='block')?'none':'block';
    twos.display = (twos.display==''||twos.display=='block')?'none':'block';

}
