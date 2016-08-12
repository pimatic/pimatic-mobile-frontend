/*
 * inspired by jQuery Mobile spinbox
 */

(function($) {
	$.widget( "mobile.timebox", {
		options: {
			// All widget options
			dmin: false,
			dmax: false,
			step: false,
			theme: false,
			mini: null,
			repButton: true,
			version: "0.1-2016-08-08",
			initSelector: "input[data-role='timebox']",
			clickEvent: "vclick",
			type: "horizontal", // or vertical
		},
		_sbox_run: function () {
			var w = this,
				timer = 150;
				
			if ( w.g.cnt > 10 ) { timer = 100; }
			if ( w.g.cnt > 30 ) { timer = 50; }
			if ( w.g.cnt > 60 ) { timer = 20; }
			
			w.g.didRun = true;
			w._offset( this, w.g.delta );
			w.g.cnt++;
			w.runButton = setTimeout( function() { w._sbox_run(); }, timer );
		},
		_offset: function( obj, direction ) {
			var tmpMinutes,
			  tmpHours,
			  val,
			  hours,
			  minutes,
			  minHours,
			  minMinutes,
			  maxHours,
			  maxMinutes,
			  output,
				w = this,
				o = this.options;

			val=w.d.input.val()
			// If the value looks like a solid 24h-time
			if (/^([01]?[0-9]|2[0-3]):[0-5][0-9]/.test(val)) {
				hours = parseInt(val.substring(0, val.indexOf(":")));
				minutes = parseInt(val.substring(val.indexOf(":") + 1));
				minHours = parseInt(o.dmin.substring(0, val.indexOf(":")));
				minMinutes = parseInt(o.dmin.substring(val.indexOf(":") + 1));
				maxHours = parseInt(o.dmax.substring(0, val.indexOf(":")));
				maxMinutes = parseInt(o.dmax.substring(val.indexOf(":") + 1));
				output = true;

				if (!w.disabled) {
					tmpHours = hours;
					if ( direction < 1 ) {
						tmpMinutes = minutes - o.step;
						while (tmpMinutes < 0) {
							tmpMinutes += 60;
							tmpHours -= 1;
						}
						if (tmpHours < 0) { tmpHours += 24; }
						if ((tmpHours * 60 + tmpMinutes) < (minHours * 60 + minMinutes)) { output = false; }
					} else {
						tmpMinutes = minutes + o.step;
						while (tmpMinutes > 59) {
							tmpMinutes -= 60;
							tmpHours += 1;
						}
						if (tmpHours > 23) { tmpHours -= 24; }
						if ((tmpHours * 60 + tmpMinutes) > (maxHours * 60 + maxMinutes)) { output = false; }
					}
					
					if (output === true) {
						if (tmpMinutes < 10) { tmpMinutes = "0" + String(tmpMinutes) }
						if (tmpHours < 10) { tmpHours = "0" + String(tmpHours) }
						w.d.input.val(String(tmpHours) + ":" + String(tmpMinutes)).trigger("change");
					}
				}
			}
		},
		_create: function() {
			var w = this,
				o = $.extend( this.options, this.element.data( "options" ) ),
				d = {
					input: this.element,
					inputWrap: this.element.parent()
				},
				touch = ( typeof window.ontouchstart !== "undefined" ),
				drag =  {
					eStart : (touch ? "touchstart" : "mousedown")+".timebox",
					eMove  : (touch ? "touchmove" : "mousemove")+".timebox",
					eEnd   : (touch ? "touchend" : "mouseup")+".timebox",
					eEndA  : (touch ? 
						"mouseup.timebox touchend.timebox touchcancel.timebox touchmove.timebox" :
						"mouseup.timebox mouseleave.timebox"
					),
					move   : false,
					start  : false,
					end    : false,
					pos    : false,
					target : false,
					delta  : false,
					tmp    : false,
					cnt    : 0
				};
				
			w.d = d;
			w.g = drag;
			
			o.theme = ( ( o.theme === false ) ?
					$.mobile.getInheritedTheme( this.element, "a" ) :
					o.theme
				);
			
			if ( w.d.input.prop( "disabled" ) ) {
				o.disabled = true;
			}
			
			if ( o.dmin === false ) { 
				o.dmin = ( /([01]?[0-9]|2[0-3]):[0-5][0-9]/.test(w.d.input.attr( "min" )) === true ) ?
					w.d.input.attr( "min" ) :
					"00:00";
			}
			if ( o.dmax === false ) { 
				o.dmax = ( /([01]?[0-9]|2[0-3]):[0-5][0-9]/.test(w.d.input.attr( "max" )) === true ) ?
					w.d.input.attr( "max" ) :
					"23:59";
			}
			if ( o.step === false) {
				o.step = ( typeof w.d.input.attr( "step") !== "undefined" ) ?
					parseFloat( w.d.input.attr( "step" ) ) :
					15;
				}
			
			o.mini = ( o.mini === null ? 
				( w.d.input.data("mini") ? true : false ) :
				o.mini );
				
			
			w.d.wrap = $( "<div>", {
					"data-role": "controlgroup",
					"data-type": o.type,
					"data-mini": o.mini,
					"data-theme": o.theme
				} )
				.insertBefore( w.d.inputWrap )
				.append( w.d.inputWrap );
			
			w.d.inputWrap.addClass( "ui-btn" );
			w.d.input.css( { textAlign: "center" } );
			
			if ( o.type !== "vertical" ) {
/*				w.d.inputWrap.css( { 
					padding: o.mini ? "1px 0" : "4px 0 3px" 
				} );
				w.d.input.css( { 
					width: o.mini ? "40px" : "50px" 
				} );*/
			} else {
				w.d.wrap.css( { 
					width: "auto"
				} );
				w.d.inputWrap.css( {
					padding: 0
				} );
			}
			
			w.d.up = $( "<div>", {
				"class": "ui-btn ui-icon-plus ui-btn-icon-notext"
			}).html( "&nbsp;" );
			
			w.d.down = $( "<div>", {
				"class": "ui-btn ui-icon-minus ui-btn-icon-notext"
			}).html( "&nbsp;" );
			
			if ( o.type !== "vertical" ) {
				w.d.wrap.prepend( w.d.down ).append( w.d.up );
			} else {
				w.d.wrap.prepend( w.d.up ).append( w.d.down );
			}
			
			w.d.wrap.controlgroup();
			
			if ( o.repButton === false ) {
				w.d.up.on( o.clickEvent, function(e) { 
					e.preventDefault();
					w._offset( e.currentTarget, 1 ); 
				});
				w.d.down.on( o.clickEvent, function(e) {
					e.preventDefault();
					w._offset( e.currentTarget, -1 );
				});
			} else {
				w.d.up.on( w.g.eStart, function(e) {
					w.d.input.blur();
					w._offset( e.currentTarget, 1 );
					w.g.move = true;
					w.g.cnt = 0;
					w.g.delta = 1;
					if ( !w.runButton ) {
						w.g.target = e.currentTarget;
						w.runButton = setTimeout( function() { w._sbox_run(); }, 500 );
					}
				});
				w.d.down.on(w.g.eStart, function(e) {
					w.d.input.blur();
					w._offset( e.currentTarget, -1 );
					w.g.move = true;
					w.g.cnt = 0;
					w.g.delta = -1;
					if ( !w.runButton ) {
						w.g.target = e.currentTarget;
						w.runButton = setTimeout( function() { w._sbox_run(); }, 500 );
					}
				});
				w.d.up.on(w.g.eEndA, function(e) {
					if ( w.g.move ) {
						e.preventDefault();
						clearTimeout( w.runButton );
						w.runButton = false;
						w.g.move = false;
					}
				});
				w.d.down.on(w.g.eEndA, function(e) {
					if ( w.g.move ) {
						e.preventDefault();
						clearTimeout( w.runButton );
						w.runButton = false;
						w.g.move = false;
					}
				});
			}
			
			if ( typeof $.event.special.mousewheel !== "undefined" ) { 
				// Mousewheel operation, if plugin is loaded
				w.d.input.on( "mousewheel", function(e,d) {
					e.preventDefault();
					w._offset( e.currentTarget, ( d < 0 ? -1 : 1 ) );
				});
			}
			
			if ( o.disabled ) {
				w.disable();
			}
			
		},
		disable: function(){
			// Disable the element
			var dis = this.d,
				cname = "ui-state-disabled";
			
			dis.input.attr( "disabled", true ).blur();
			dis.inputWrap.addClass( cname );
			dis.up.addClass( cname );
			dis.down.addClass( cname );
			this.options.disabled = true;
		},
		enable: function(){
			// Enable the element
			var dis = this.d,
				cname = "ui-state-disabled";
			
			dis.input.attr( "disabled", false );
			dis.inputWrap.removeClass( cname );
			dis.up.removeClass( cname );
			dis.down.removeClass( cname );
			this.options.disabled = false;
		}
	});
})( jQuery );
