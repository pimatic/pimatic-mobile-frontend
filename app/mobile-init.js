// Update configuration to our liking
$( document ).on( "mobileinit", function() {
  $.extend( $.mobile , {
    ajaxEnabled: false,
    hoverDelay: 300,
    defaultPageTransition: 'slide',
    getMaxScrollForTransition: function(){return 5;}
  });

  $.mobile.toolbar.tapToggle = false;
});
