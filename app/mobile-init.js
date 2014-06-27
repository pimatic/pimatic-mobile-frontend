// Update configuration to our liking
$( document ).on( "mobileinit", function() {
  $.extend( $.mobile , {
    ajaxEnabled: false,
    hoverDelay: 300,
    defaultPageTransition: 'slide',
    getMaxScrollForTransition: function(){return 5;}
  });
  //path to nop
  //$.mobile.resetActivePageHeight = function(){};
  //console.log($.mobile.resetActivePageHeight);

  $.mobile.toolbar.tapToggle = false;
});
