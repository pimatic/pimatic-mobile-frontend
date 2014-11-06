/*!
 * jQuery.textcomplete.js
 *
 * Repositiory: https://github.com/yuku-t/jquery-textcomplete
 * License:     MIT
 * Author:      Yuku Takahashi
 */

;(function ($) {

  'use strict';

  /**
   * Exclusive execution control utility.
   */
  var lock = function (func) {
    var free, locked;
    free = function () { locked = false; };
    return function () {
      var args;
      if (locked) return;
      locked = true;
      args = toArray(arguments);
      args.unshift(free);
      func.apply(this, args);
    };
  };

  /**
   * Convert arguments into a real array.
   */
  var toArray = function (args) {
    var result;
    result = Array.prototype.slice.call(args);
    return result;
  };

  /**
   * Bind the func to the context.
   */
  var bind = function (func, context) {
    if (func.bind) {
      // Use native Function#bind if it's available.
      return func.bind(context);
    } else {
      return function () {
        func.apply(context, arguments);
      };
    }
  };

  /**
   * Get the styles of any element from property names.
   */
  var getStyles = (function () {
    var color;
    color = $('<div></div>').css(['color']).color;
    if (typeof color !== 'undefined') {
      return function ($el, properties) {
        return $el.css(properties);
      };
    } else {  // for jQuery 1.8 or below
      return function ($el, properties) {
        var styles;
        styles = {};
        $.each(properties, function (i, property) {
          styles[property] = $el.css(property);
        });
        return styles;
      };
    }
  })();

  /**
   * Default template function.
   */
  var identity = function (obj) { return obj; };

  /**
   * Memoize a search function.
   */
  var memoize = function (func) {
    var memo = {};
    return function (term, callback) {
      if (memo[term]) {
        callback(memo[term]);
      } else {
        func.call(this, term, function (data) {
          memo[term] = (memo[term] || []).concat(data);
          callback.apply(null, arguments);
        });
      }
    };
  };

  /**
   * Determine if the array contains a given value.
   */
  var include = function (array, value) {
    var i, l;
    if (array.indexOf) return array.indexOf(value) != -1;
    for (i = 0, l = array.length; i < l; i++) {
      if (array[i] === value) return true;
    }
    return false;
  };

  /**
   * Textarea manager class.
   */
  var Completer = (function () {
    var html, css, $baseWrapper, $baseList;

    html = {
      wrapper: '<div class="textcomplete-wrapper"></div>',
      list: '<div class="dropdown-menu"><ul class="format"></ul><ul class="autocomplete"></ul></div>'
    };
    css = {
      wrapper: {
        position: 'relative'
      },
      list: {
        position: 'absolute',
        top: 0,
        left: 0,
        zIndex: '100',
        display: 'none'
      }
    };
    $baseWrapper = $(html.wrapper).css(css.wrapper);
    $baseList = $(html.list).css(css.list);

    function Completer($el, strategies) {
      var $wrapper, $list, focused;
      $list = $baseList.clone();
      this.el = $el.get(0);  // textarea element
      this.$el = $el;
      $wrapper = prepareWrapper(this.$el);

      // Refocus the textarea if it is being focused
      focused = this.el === document.activeElement;
      this.$el.wrap($wrapper).before($list);
      if (focused) { this.el.focus(); }

      this.listView = new ListView($list, this);
      this.strategies = strategies;
      this.$el.on('keyup', bind(this.onKeyup, this));
      this.$el.on('keydown', bind(this.listView.onKeydown, this.listView));

      // Global click event handler
      $(document).on('click', bind(function (e) {
        if (e.originalEvent && !e.originalEvent.keepTextCompleteDropdown) {
          this.listView.deactivate();
        }
      }, this));
    }

    /**
     * Completer's public methods
     */
    $.extend(Completer.prototype, {

      /**
       * Show autocomplete list next to the caret.
       */
      renderList: function (term, lastText, data) {
        this.listView.clear();

        this.lastData = data;
        data.autocomplete = this.filterData(term, data.autocomplete);

        if (data.autocomplete.length || data.format.length) {
          this.listView.setPosition(this.getCaretPosition(term, lastText, data.autocomplete));
          if (!this.listView.shown) {
            this.listView
                .clear()
                .activate();
            this.listView.strategy = this.strategy;
          }
          this.listView.render(data);
        }
        
        if (!this.listView.data.autocomplete.length 
             && !this.listView.data.format.length
             && this.listView.shown) {
          this.listView.deactivate();
        }
      },

      searchCallbackFactory: function (term, free) {
        var self = this;
        var text = self.getTextFromHeadToCaret();
        return function (data, keep) {
          self.renderList(term, text, data);
          if (!keep) {
            // This is the last callback for this search.
            free();
            self.clearAtNext = true;
            self.onKeyup();
          }
        };
      },

      /**
       * Keyup event handler.
       */
      onKeyup: function (e, force) {
        var searchQuery, term;

        searchQuery = this.extractSearchQuery(this.getTextFromHeadToCaret());
        if (searchQuery.length) {
          term = searchQuery[1];
          if (!force && this.term === term) return; // Ignore shift-key or something.
          this.search(searchQuery);
        } else {
          this.term = null;
          this.listView.deactivate();
        }
      },

      onSelect: function (value) {
        var pre, post, newSubStr, fullText;
        pre = this.getTextFromHeadToCaret();
        post = this.el.value.substring(this.el.selectionEnd);
        pre = this.strategy.replace(pre, value);
        fullText = pre + post;
        this.el.value = fullText;
        this.el.focus();
        this.strategy.change(fullText);
        this.el.selectionStart = this.el.selectionEnd = pre.length;
        this.onKeyup(null, true);
      },

      getCommonPart: function(trigger, suggestion) {
        var i, search;
        i = Math.min(trigger.length, suggestion.length);
        while (i >= 0) {
          search = suggestion.substring(0, i);
          if (trigger.toLowerCase().lastIndexOf(search.toLowerCase()) === trigger.length - search.length) {
            break;
          } else {
            i--;
          }
        }
        return suggestion.substring(0, i);
      },

      // Helper methods
      // ==============

      /**
       * Returns caret's relative coordinates from textarea's left top corner.
       */
      getCaretPosition: function (term, text, autocomplete) {
        // Browser native API does not provide the way to know the position of
        // caret in pixels, so that here we use a kind of hack to accomplish
        // the aim. First of all it puts a div element and completely copies
        // the textarea's style to the element, then it inserts the text and a
        // span element into the textarea.
        // Consequently, the span element's position is the thing what we want.

        //if (this.el.selectionEnd === 0) return;
        var properties, css, $div, $span, position, text;

        properties = ['border-width', 'font-family', 'font-size', 'font-style',
          'font-variant', 'font-weight', 'height', 'letter-spacing',
          'word-spacing', 'line-height', 'text-decoration', 'text-align',
          'width', 'padding-top', 'padding-right', 'padding-bottom',
          'padding-left', 'margin-top', 'margin-right', 'margin-bottom',
          'margin-left'
        ];
        css = $.extend({
          position: 'absolute',
          overflow: 'auto',
          'white-space': 'pre-wrap',
          top: 0,
          left: -9999
        }, getStyles(this.$el, properties));

        function findLongestPrefix(list) {
            if(list.length === 0) return "";
            var prefix = list[0];
            var prefixLen = prefix.length;
            for (var i = 1; i < list.length && prefixLen > 0; i++) {
                var word = list[i];
                // The next line assumes 1st char of word and prefix always match.
                // Initialize matchLen to -1 to test entire word.
                var matchLen = 0;
                var maxMatchLen = Math.min(word.length, prefixLen);
                while (++matchLen < maxMatchLen) {
                    if (word.charAt(matchLen).toLowerCase() != prefix.charAt(matchLen).toLowerCase()) {
                        break;
                    }
                }
                prefixLen = matchLen;
            }
            return prefix.substring(0, prefixLen);
        }

        var s = findLongestPrefix(autocomplete);
        var temp = this.getCommonPart(text, s);

        if(text.length >= temp.length) {
          text = text.substring(0, text.length-temp.length);
        }
        $div = $('<div></div>').css(css).text(text);
        $span = $('<span></span>').text('&nbsp;').appendTo($div);
        this.$el.before($div);
        position = $span.position();
        position.top += $span.height() - this.$el.scrollTop();
        $div.remove();
        return position;
      },

      getTextFromHeadToCaret: function () {
        var text, selectionEnd, range;
        selectionEnd = this.el.selectionEnd;
        if (typeof selectionEnd === 'number') {
          text = this.el.value.substring(0, selectionEnd);
        } else if (document.selection) {
          range = this.el.createTextRange();
          range.moveStart('character', 0);
          range.moveEnd('textedit');
          text = range.text;
        }
        return text;
      },

      filterData: function(term, autocomplete) {
        var text = this.getTextFromHeadToCaret();
        var newPart = text.substring(term.length, text.length);
        if(newPart.lenght > 0) {
          var newData = [];
          for(var i=0; i < autocomplete.length; i++) {
            if(autocomplete[i].substring(0, newPart.lenght) === newPart) {
              newData.push(autocomplete[i]);
            }
          }
          return newData;
        }
        return autocomplete;
      },

      /**
       * Parse the value of textarea and extract search query.
       */
      extractSearchQuery: function (text) {
        // If a search query found, it returns used strategy and the query
        // term. If the caret is currently in a code block or search query does
        // not found, it returns an empty array.

        var i, l, strategy, match;
        for (i = 0, l = this.strategies.length; i < l; i++) {
          strategy = this.strategies[i];
          strategy.ac = this;
          match = text.match(strategy.match);
          if (match) { return [strategy, match[strategy.index]]; }
        }
        return [];
      },

      search: function(searchQuery) {
        var term, strategy;
        this.strategy = searchQuery[0];
        term = searchQuery[1];
        // prerender it with last data
        //if(this.lastData) {
        //  this.renderList(term, text, this.lastData);
        //}
        return this.searchOnline(term);
      },

      searchOnline: lock(function (free, term) {
        this.term = term;
        this.strategy.search(term, this.searchCallbackFactory(term, free));
      })


    });

    /**
     * Completer's private functions
     */
    var prepareWrapper = function ($el) {
      return $baseWrapper.clone().css('display', $el.css('display'));
    };

    return Completer;
  })();

  /**
   * Dropdown menu manager class.
   */
  var ListView = (function () {

    function ListView($el, completer) {
      this.data = {autocomplete: [], format: []};
      this.$el = $el;
      this.index = 0;
      this.completer = completer;

      this.$el.on('click', 'li.textcomplete-item', bind(this.onClick, this));
      this.$el.on('change', 'select', bind(this.onChange, this));
    }

    $.extend(ListView.prototype, {
      shown: false,

      render: function (data) {
        var html, i, l, index, val;

        var displayCount = this.strategy.maxCount;
        if (data.autocomplete.length > this.strategy.maxCount) {
          displayCount--;
        }

        this.data.format = data.format;
        if(data.format.length){
          html = '';
          for (i = 0, l = data.format.length; i < l; i++) {
            val = data.format[i];
            html += '<li class="textcomplete-item textcomplete-format">';
            html += val;
            html += '</li>';
          }
          this.$el.find('.format').append(html);
        }

        html = '';
        for (i = 0, l = data.autocomplete.length; i < l; i++) {
          val = data.autocomplete[i];
          if (include(this.data.autocomplete, val)) continue;
          index = this.data.autocomplete.length;
          this.data.autocomplete.push(val);
          html += '<li class="textcomplete-item" data-index="' + index + '"><a>';
          html +=   this.strategy.template(val);
          html += '</a></li>';
          if (this.data.autocomplete.length === displayCount) break;
        }
        this.displayCount = this.data.autocomplete.length;
        if (data.autocomplete.length > displayCount) {
          html += '<li class="textcomplete-more" data.autocomplete-index="' + displayCount + '">';
          html += '<select>';
          html += '<option value="more">...</option>';
          for (i = displayCount, l = data.autocomplete.length; i < l; i++) {
            val = data.autocomplete[i];
            if (include(this.data.autocomplete, val)) continue;
            index = this.data.autocomplete.length;
            this.data.autocomplete.push(val);
            html += '<option data-index="' + index + '" value="' + index + '">' + val + '</option>';
          }
          html += '</select">';
          html += '</li>';
          //count select
          this.displayCount++;
        }
        this.$el.find('.autocomplete').append(html);
        if (this.data.autocomplete.length === 0 && data.format.length === 0) {
          this.deactivate();
        } else {
          if(this.data.autocomplete.length) {
            this.activateIndexedItem();
          } else {
            this.reposition();
          }
        }
      },

      clear: function () {
        this.data.autocomplete = [];
        this.data.format = [];
        this.$el.find('.autocomplete').html('');
        this.$el.find('.format').html('');
        this.index = 0;
        return this;
      },

      activateIndexedItem: function () {
        var $item;
        this.$el.find('.active').removeClass('active');
        this.getActiveItem().addClass('active');
        this.reposition();
      },

      getActiveItem: function () {
        return $(this.$el.find('.autocomplete').children().get(this.index));
      },

      activate: function () {
        if (!this.shown) {
          this.$el.show();
          this.shown = true;
        }
        return this;
      },

      deactivate: function () {
        if (this.shown) {
          this.$el.hide();
          this.shown = false;
          this.data = {autocomplete: [], format: []};
          this.index = null;
        }
        return this;
      },

      setPosition: function (position) {
        this.$el.css(position);
        return this;
      },

      select: function (index) {
        this.completer.onSelect(this.data.autocomplete[index]);
        this.deactivate();
      },

      reposition: function() {
        var $wrapper = $('.textcomplete-wrapper');
        var rightOffset = this.$el.offset().left + this.$el.outerWidth();
        var bottomOffset = this.$el.offset().top + this.$el.outerHeight();
        var textareaRight = $wrapper.offset().left + $wrapper.outerWidth();
        var textareaBottom = $wrapper.offset().left + $wrapper.outerWidth();
        if(rightOffset > textareaRight) {
          var rel = rightOffset - textareaRight;
          var left = parseInt(this.$el.css('left').replace('px',''), 10);
          this.$el.css('left', left - rel);
        }
      },

      onKeydown: function (e) {
        var $item;
        if (!this.shown) return;
        if (e.keyCode === 27) {         // ESC
            this.deactivate();
        } else if (e.keyCode === 38) {         // UP
          e.preventDefault();
          if (this.index === 0) {
            this.index = this.displayCount-1;
          } else {
            this.index -= 1;
          }
          this.activateIndexedItem();
        } else if (e.keyCode === 40) {  // DOWN
          e.preventDefault();
          if (this.index === this.displayCount-1) {
            this.index = 0;
          } else {
            this.index += 1;
          }
          this.activateIndexedItem();
        } else if (e.keyCode === 13 || e.keyCode === 9) {  // ENTER or TAB
          var activeItem = this.getActiveItem();
          var index = parseInt(activeItem.data('index'));
          //unless more is selected
          if(activeItem.hasClass('textcomplete-more')) {
            activeItem.find('select').focus();
          } else {
            e.preventDefault();
            this.select(index);
          }
        }
      },

      onClick: function (e) {
        var $e = $(e.target);
        e.originalEvent.keepTextCompleteDropdown = true;
        if (!$e.hasClass('textcomplete-item')) {
          $e = $e.parents('li.textcomplete-item');
        }
        this.select(parseInt($e.data('index')));
      },

      onChange: function (e) {
        var $e = $(e.target);
        this.select(parseInt($e.val()));
      }
    });

    return ListView;
  })();

  $.fn.textcomplete = function (strategies) {
    var i, l, strategy;
    for (i = 0, l = strategies.length; i < l; i++) {
      strategy = strategies[i];
      if (!strategy.template) {
        strategy.template = identity;
      }
      if (strategy.index == null) {
        strategy.index = 2;
      }
      if (strategy.cache) {
        strategy.search = memoize(strategy.search);
      }
      strategy.maxCount || (strategy.maxCount = 10);
    }
    new Completer(this, strategies);

    return this;
  };

})(window.jQuery || window.Zepto);
