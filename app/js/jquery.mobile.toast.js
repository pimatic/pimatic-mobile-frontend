/*
 * jQuery Mobile Framework : plugin to provide a simple popup (toast notification) similar to Android Toast Notifications
 * Copyright (c) jjoe64
 * licensed under LGPL
 * 
 */
(function($, undefined ) {

$.widget( "mobile.toast", $.mobile.widget, {
	options: {
		/**
		 * string|integer
		 * 'short', 'long' or a integer (milliseconds)
		 */
		duration: 'short',
		initSelector: ":jqmData(role='toast')"
	},
	_create: function(){
		var $el = this.element
		$el.addClass('ui-toast')
		$el.hide()
		self = this
		$('body').bind('showToast', function() {
		  self.cancel()
		})
	},
	/**
	 * fadeIn the toast notification and automatically fades out after the given time
	 */
	show: function() {
	  $('body').trigger('showToast') // cancels all active toasts
	  
		var $el = this.element
		
		$el.css('top', '0px')
		$el.css('left', '0px')

		$el.show();
		var bw = $('body').width()
		var bh = $('body').height()
		
		var top = (bh*3/4) - $el.height()/2
		var left = bw/2 - $el.outerWidth()/2
		$el.data('top', top)
		$el.css('top', top+'px')
		$el.css('left', left+'px')
		
		// fade in and fade out after the given time
		var millis = 4000;
		$el.fadeIn().delay(millis).fadeOut('slow')
	},
	/**
	 * cancel and hides the toast
	 */
	cancel: function() {
	  var $el = this.element;
    $el.stop(true, true).hide()
	}
});
  
//auto self-init widgets
$( document ).bind( "pagecreate create", function( e ){
	$( $.mobile.toast.prototype.options.initSelector, e.target )
		.toast();
});
	
})( jQuery );

