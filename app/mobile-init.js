// Update configuration to our liking
$( document ).on( "mobileinit", function() {
  $.extend( $.mobile , {
    ajaxEnabled: false,
    hoverDelay: 100,
    defaultPageTransition: 'slide',
    getMaxScrollForTransition: function(){return 999999;}
  });
});
