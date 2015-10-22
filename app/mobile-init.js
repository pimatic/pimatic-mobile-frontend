// Update configuration to our liking
$( document ).on( "mobileinit", function() {
  $.extend( $.mobile , {
    ajaxEnabled: false,
    hoverDelay: 300,
    defaultPageTransition: 'slide',
    getMaxScrollForTransition: function(){return 5;}
  });

  // monkeypatch resetActivePageHeight function because we are using overthrow
  $.mobile.resetActivePageHeight = function( height ) {
    var page = $( "." + $.mobile.activePageClass );
    var screenHeight = $.mobile.getScreenHeight();
    page.css( "min-height", screenHeight);
    $('#nav-panel').css('height', screenHeight);
  };
  $.mobile.toolbar.tapToggle = false; 

  if ('addEventListener' in document) {
    document.addEventListener('DOMContentLoaded', function() {
      FastClick.attach(document.body); 
    }, false);
  }

});
