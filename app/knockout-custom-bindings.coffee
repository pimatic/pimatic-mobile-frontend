( ->

  setIconClass = ($ele, icon) ->
    # remove old icon-class
    classes = (
      cl for cl in $ele.attr('class').split(" ") when cl.lastIndexOf('ui-icon-') isnt 0
    )
    classes.push('ui-icon-'+icon)
    # add new one
    $ele.attr("class", classes.join(" "));

  ko.bindingHandlers.jqmbutton = {

    init: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      return


    update: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      # Handle text binding
      if valueUnwrapped.text?
        textValue = ko.unwrap(valueUnwrapped.text)
        $ele.text(textValue)
      if valueUnwrapped.icon?
        icon = ko.unwrap(valueUnwrapped.icon)
        setIconClass($ele, icon)
      if valueUnwrapped.enabled?
        enabled = ko.unwrap(valueUnwrapped.enabled)
        if enabled
          try 
            $ele.button("enable")
          catch e 
            $ele.removeClass("ui-state-disabled")
        else 
          try
            $ele.button("disable")
          catch e
            $ele.addClass("ui-state-disabled")
      return
  }

  ko.bindingHandlers.jqmlistitem = {
    update: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      # Handle icon binding
      if value.icon?
        icon = ko.unwrap(value.icon)
        setIconClass($ele, icon)
  }

  ko.bindingHandlers.jqmenabled = {
    update: (element, valueAccessor, allBindings) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      switch element.type
        when "select-one"
          if $ele.data('mobileFlipswitch')?
            if valueUnwrapped then $ele.flipswitch('enable') else $ele.flipswitch('disable') 
          else
            if valueUnwrapped then $ele.selectmenu('enable') else $ele.selectmenu('disable') 
        else
          if valueUnwrapped then $ele.textinput('enable') else $ele.textinput('disable')
      return
  }

  ko.bindingHandlers.jqmchecked = {
    init: (element, valueAccessor, allBindings) ->
      init: ko.bindingHandlers.checked.init(element, valueAccessor, allBindings)
      $(element).checkboxradio()
      return
    
    update: (element, valueAccessor) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $(element).checkboxradio("refresh")
      return
    }

  ko.bindingHandlers.jqmselectedOptions = {
    init: (element, valueAccessor) ->
      value = valueAccessor()
      $ele = $(element)
      $ele.on('change', => 
        val = $ele.val()
        unless val? then val = []
        value(val)
      )

    update: (element, valueAccessor) ->
      value = valueAccessor()
      $ele = $(element)
      $ele.val(value())
      $ele.selectmenu( "refresh", true )
      return
    }

  ko.bindingHandlers.jqmflipswitch = {
    init: (element, valueAccessor) ->
      value = valueAccessor()
      $ele = $(element)
      $ele.flipswitch()
      if ko.isObservable(value)
        $ele.on('change', => 
          val = $ele.val()
          switch val
            when "true" then val = true
            when "false" then val = false
          if ko.unwrap(value) isnt val
            value(val)
        )

    update: (element, valueAccessor) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      $ele = $(element)
      if typeof valueUnwrapped is "boolean"
        valueUnwrapped = "#{valueUnwrapped}"
      $ele.val(valueUnwrapped)
      $ele.flipswitch('refresh')
      return
    }

  ko.bindingHandlers.jqmoptions = {
    init: (element, valueAccessor, allBindings) ->
      ko.bindingHandlers.options.init(element, valueAccessor, allBindings)
      $(element).selectmenu()
      return

    update: (element, valueAccessor, allBindings) ->
      ko.bindingHandlers.options.update(element, valueAccessor, allBindings)
      value = allBindings()?.value()
      $(element).val(value) if value?
      $(element).selectmenu("refresh")
      return
    }

  ko.bindingHandlers.jqmlistview = {
    init: (element, valueAccessor, allBindings) ->
      setTimeout( ( ->
        $(element).listview()
      ), 1)
      return
    
    update: (element, valueAccessor, allBindings) ->
      valueAccessor()
      setTimeout( ( ->
        try
          $(element).listview('refresh')
        catch e
          # ignore
       ), 1)
      return
    }

  ko.bindingHandlers.jqmtextinput = {
    init: (element, valueAccessor, allBindings) ->
      $(element).textinput(enhanced: true)
      ko.bindingHandlers.textInput.init(element, valueAccessor, allBindings)
      return
    }

  ko.bindingHandlers.sparkline = {
    init: (element, valueAccessor) ->
      ko.bindingHandlers.sparkline.update(element, valueAccessor)
      setTimeout( ( -> $.sparkline_display_visible() ), 100 )
      

    update: (element, valueAccessor) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      data = ko.unwrap(valueUnwrapped.data)
      tooltipFormatter = valueUnwrapped.tooltipFormatter
      $(element).sparkline(data, {
        disableTooltips: yes
        height: 19, # height auto is slow
        type: 'line',
        lineColor: '#7c7c7c',
        fillColor: '#cccccc',
        spotColor: '#666666',
        minSpotColor: null,
        maxSpotColor: null,
        highlightSpotColor: null,
        highlightLineColor: null,
        drawNormalOnTop: false,
        tooltipFormatter: tooltipFormatter
      })
    }

  ko.bindingHandlers.toast = {
    init: (element, valueAccessor) ->
      text = valueAccessor()
      textUnwrapped = ko.unwrap(text)
      $ele = $(element)
      $ele.text(textUnwrapped)
      $ele.toast()
      $ele.toast('show')
      height = $ele.outerHeight() + 2
      $ele.parent().find('.ui-toast').each( ->
        if this is element then return
        $toast = $(this)
        $toast.addClass('animated-toast')
        newTop = $toast.data('top') + height
        $toast.css('top', newTop + 'px')
        $toast.data('top', newTop)
        return
      )
  }

  ko.bindingHandlers.tooltip = {

    init_tooltip: (target, tooltip, container) ->
      containerHeight = Math.min(container.parent().height(), $(window).height())
      containerWidth = Math.min(container.parent().width(), $(window).width())
      if containerWidth < tooltip.outerWidth() * 1.5
        tooltip.css "max-width", containerWidth / 2
      else
        tooltip.css "max-width", 340
      
      pos_left = target.offset().left + (target.outerWidth() / 2) - (tooltip.outerWidth() / 2)
      pos_top = target.offset().top - tooltip.outerHeight() - 20
      if pos_left < 0
        pos_left = target.offset().left + target.outerWidth() / 2 - 20
        tooltip.addClass "left"
      else
        tooltip.removeClass "left"
      if pos_left + tooltip.outerWidth() > containerWidth
        pos_left = target.offset().left - tooltip.outerWidth() + target.outerWidth() / 2 + 20
        tooltip.addClass "right"
      else
        tooltip.removeClass "right"
      if pos_top + tooltip.outerHeight() + 30 > containerHeight
        pos_top -= 10
        tooltip.removeClass "top"
      else
        pos_top = target.offset().top + target.outerHeight() - 10
        tooltip.addClass "top"
        
      tooltip
      .removeClass('animated-tooltip')
      .css(
        left: pos_left
        top: pos_top
        opacity: 0
      )
      tooltip[0].offsetWidth = tooltip[0].offsetWidth #retrigger the transition
      tooltip.addClass('animated-tooltip').css(
        top: pos_top + 20
      ).animate(
        opacity: 1
      , 100)
      return tooltip

    remove_tooltip: (target, tooltip) ->
      ko.bindingHandlers.tooltip.doRemove = yes
      tooltip.animate(
        opacity: 0
      , 200, ( => 
        if ko.bindingHandlers.tooltip.doRemove
          tooltip.removeClass('animated-tooltip').remove() 
      ) )

    init: (element, valueAccessor) ->
      target = $(element)
      value = valueAccessor()
      target.bind("vclick", ->
        tip = ko.unwrap(value)
        return false  if not tip or tip is ""
        tooltip = $("#tooltip")
        if tooltip.length is 0
          tooltip = $("<div id=\"tooltip\" class=\"ui-corner-all\"></div>")
          tooltip.css("opacity", 0).html(tip).appendTo('body')
        ko.bindingHandlers.tooltip.doRemove = no
        ko.bindingHandlers.tooltip.subscribtion?.dispose()
        clearInterval(ko.bindingHandlers.tooltip.interval)
        clearTimeout(ko.bindingHandlers.tooltip.timeout)
        $(window).off('touchstart', ko.bindingHandlers.tooltip.touchdispose)

        container = target.parents('.owl-item')
        container = target.parents('.ui-content.overthrow') if container.length is 0

        ko.bindingHandlers.tooltip.init_tooltip(target, tooltip, container)
        ko.bindingHandlers.tooltip.subscribtion = ko.computed( =>
          tip = valueAccessor()()
          tooltip.html(tip)
          ko.bindingHandlers.tooltip.init_tooltip(target, tooltip, container)
        )

        # $(window).resize(init_tooltip)
        removeTooltip = ( (event) => 
          clearInterval(ko.bindingHandlers.tooltip.interval)
          clearTimeout(ko.bindingHandlers.tooltip.timeout)
          ko.bindingHandlers.tooltip.subscribtion.dispose()
          $(window).off('touchstart', ko.bindingHandlers.tooltip.touchdispose)
          container.off("scroll", removeTooltip)
          tooltip.off("vclick", removeTooltip)
          target.off("mouseleave", mouseleave) if mouseleave?
          if event? and $(event.target).parents('#tooltip').length isnt 0
            href = $(event.target).attr('href')
            event.preventDefault() if href is "" or href.match(/^#.*/)
            event.stopImmediatePropagation()
            $(event.target).click()
          ko.bindingHandlers.tooltip.remove_tooltip(target, tooltip)
          return true
        )
        isTouchSupported = 'ontouchstart' in window
        unless isTouchSupported
          target.one("mouseleave", mouseleave = (e)  ->
            clearInterval(ko.bindingHandlers.tooltip.interval)
            ko.bindingHandlers.tooltip.interval = setInterval(  ->
              if $("#tooltip:hover").length is 0
                removeTooltip()
            , 1000)
          )
        clearTimeout(ko.bindingHandlers.tooltip.timeout)
        ko.bindingHandlers.tooltip.touchdispose = removeTooltip
        ko.bindingHandlers.tooltip.timeout = setTimeout( ->
          tooltip.one("vclick", removeTooltip)
          $(window).one('touchstart', ko.bindingHandlers.tooltip.touchdispose)
        , 310)
        container.one("scroll", removeTooltip)
        return
      )
}

  ScrollArea = (element) ->
    @element = element
    @$element = $(element)
    @scrollMargin = Math.floor(@$element.innerHeight() / 10)
    @offset = @$element.offset()
    @innerHeight = @$element.innerHeight()
    @scrollDeltaMin = 5
    @scrollDeltaMax = 30
  ScrollArea::scroll = (x, y) ->
    topLimit = @scrollMargin + @offset.top
    speed = undefined
    scrollDelta = 0
    if y < topLimit
      speed = (topLimit - y) / @scrollMargin
      scrollDelta = -(speed * (@scrollDeltaMax - @scrollDeltaMin) + @scrollDeltaMin)
    bottomLimit = @offset.top + @innerHeight - @scrollMargin
    if y > bottomLimit
      speed = (y - bottomLimit) / @scrollMargin
      scrollDelta = speed * (@scrollDeltaMax - @scrollDeltaMin) + @scrollDeltaMin
    if scrollDelta != 0  
      scrollPos = @$element.scrollTop()
      scrolled = @$element.scrollTop(scrollPos + scrollDelta)
      scrollDelta = @$element.scrollTop( )- scrollPos
    return scrollDelta

  ko.bindingHandlers.sortable = {
    init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
      value = valueAccessor()
      items = value.items

      getElementBeforeAndAfter = (ele) =>
        eleBefore = null
        eleAfter = null
        eleBeforePos = null
        eleAfterPos = null

        dragPos = ele.offset()
        #dragPos.bottom = dragPos.top + ele.outerHeight()
        #dragPos.middle = (dragPos.top + dragPos.bottom) / 2.0

        $(element).find('.sortable').each((i, o) =>
          if o is ele[0] then return

          pos = $(o).offset()
          #pos.bottom = pos.top + $(o).outerHeight()
          #pos.middle = (pos.top + pos.bottom) / 2.0

          if pos.top < dragPos.top
            if (not eleBeforePos?) or pos.top > eleBeforePos.top
              [eleBefore, eleBeforePos] = [o, pos]
          else if pos.top > dragPos.top
            if (not eleAfterPos?) or pos.top < eleAfterPos.top 
              [eleAfter, eleAfterPos] = [o, pos] 
        )
        return {eleBefore, eleAfter}
      
      $(element).on("MSPointerDown touchstart mousedown", '.handle', (event) ->
        parent = $(this).parents('.sortable')

        updatePlaceholder = =>
          pos = parent.offset()
          eleHeight = parent.outerHeight()
          pos.bottom = pos.top + eleHeight
          {eleBefore, eleAfter} = getElementBeforeAndAfter(parent)
          # reset elements css
          sortableElements = $(element).find('.sortable')
          sortableElements.each((i, o) =>
            if o is parent[0] then return
            # $(o).css('background-color', 'white')
            $(o).css('margin-bottom', 0)
            $(o).css('margin-top', 0)
            #$(o).attr('style', '')
          )
          # Just for debugging
          # if eleBefore? then $(eleBefore).css('background-color', 'green')
          # if eleAfter? then $(eleAfter).css('background-color', 'red')
          if sortableElements.length > 1
            if eleBefore? 
              eleBeforePos = $(eleBefore).offset()
              eleBeforePos.width = $(eleBefore).outerHeight()
              eleBeforePos.middle = eleBeforePos.top + eleBeforePos.width / 2.0
              eleBeforePos.bottom = eleBeforePos.top + eleBeforePos.width
              if pos.top < eleBeforePos.middle
                $(eleBefore).css('margin-top', eleHeight)
              else
                if eleAfter?
                  eleAfterPos = $(eleAfter).offset()
                  eleAfterPos.width = $(eleAfter).outerHeight()
                  eleAfterPos.middle = eleAfterPos.top + eleAfterPos.width / 2.0
                  if pos.bottom > eleAfterPos.middle and pos.top > eleBeforePos.bottom + eleHeight/2.0
                    $(eleAfter).css('margin-bottom', eleHeight)
                  else
                    $(eleBefore).css('margin-bottom', eleHeight)
                else
                  $(eleBefore).css('margin-bottom', eleHeight)
            else if eleAfter?
              $(eleAfter).css('margin-top', eleHeight)
          else
            # No other elements are there, to be used as placeholder, spreserve the space for 
            # the element, by removinf the negative margin bottom
            parent.css('margin-bottom', '')

          offset = pos.top - parent.offset().top
          if offset isnt 0
            parent.data('plugin_pep').doMoveTo(0, offset)

        updateOrder = =>
          {eleBefore, eleAfter} = getElementBeforeAndAfter(parent)
          unless eleBefore is null and eleAfter is null
            inHand = ko.dataFor(parent[0])
            before = (if eleBefore? then ko.dataFor(eleBefore))
            after = (if eleAfter? then ko.dataFor(eleAfter))
            if items?
              sourceIndex = items.indexOf(inHand) 
              targetIndex = (
                if eleBefore?
                  index = items.indexOf(before) + 1
                  if sourceIndex < index then index--
                  index
                else 0
              )
              #console.log sourceIndex, targetIndex
              if sourceIndex >= 0 and targetIndex >= 0 and sourceIndex isnt targetIndex
                #  get the item to be moved
                underlyingList = ko.utils.unwrapObservable(items)
                itemToMove = underlyingList[sourceIndex]
                # notify 'beforeChange' subscribers
                items.valueWillMutate()
                # move from source index ...
                underlyingList.splice sourceIndex, 1
                # ... to target index
                underlyingList.splice targetIndex, 0, itemToMove
                # notify subscribers
                items.valueHasMutated()
                if value.sorted?
                  value.sorted.call(viewModel, inHand, before, after)
            else if value.sorted?
              value.sorted.call(viewModel, inHand, before, after)

        x = null
        y = null
        scrollArea = null
        timer = null
        animationClassTimeout = null
        parent.pep(
          place: false
          axis: 'y'
          shouldEase: false
          constrainTo: 'parent'
          droppable: value.droppable or '.droppable'
          overlapFunction: ($a, $b) =>
            rect1 = $a[0].getBoundingClientRect()
            rect2 = $b[0].getBoundingClientRect()
            drop = rect2.bottom-rect1.bottom > -20 and rect2.bottom-rect1.bottom < 10
            return drop
          start: =>
            # fix the hight of the element while sorting
            $(element).css('height', $(element).height())
            clearTimeout(animationClassTimeout)
            value.isSorting(yes) if value.isSorting?
            $(element).addClass("noAnimation")
            parent.css('margin-bottom', -parent.innerHeight())
            parents = $(element).parents(value.scroller or '.ui-content.overthrow')
            scrollArea = new ScrollArea(parents[0])
            
            lastX = null
            lastY = null
            timer = setInterval( (=> 
              scrollDelta = scrollArea.scroll(x, y)
              if scrollDelta != 0
                parent.data('plugin_pep').doMoveTo(0, scrollDelta)
            ) , 100);
          stop: (ev, obj) =>
            clearTimeout(timer)
            onDropRegion = obj.activeDropRegions.length > 0
            $(obj.activeDropRegions).each( (i, o) =>
              value.drop.call(viewModel, ko.dataFor(parent[0]), o) if value.drop?
            )
            unless onDropRegion then updateOrder()
            pepObj = parent.data('plugin_pep')
            $.pep.unbind( parent )
            $(element).find('.sortable').attr('style', '')
            $(element).css('height', '')
            value.isSorting(no) if value.isSorting?
            animationClassTimeout = setTimeout( (=>
              $(element).removeClass("noAnimation")
            ), 100)
            parent.removeClass('ui-btn-active')
          drag: (ev, obj) => 
            x = ev.pageX
            y = ev.pageY
            updatePlaceholder()
            return true

        )
        parent.data('plugin_pep').handleStart(event)
        event.stopImmediatePropagation()
      )

  }

  ko.bindingHandlers.jqmselectvalue = {
    init: (element, valueAccessor, allBindingsAccessor, viewModel) ->
      if typeof ko.bindingHandlers.value.init isnt "undefined"
        ko.bindingHandlers.value.init element, valueAccessor, allBindingsAccessor, viewModel
      # access value
      value = valueAccessor()
      ko.unwrap(value)

    update: (element, valueAccessor, allBindingsAccessor, viewModel) ->
      if typeof ko.bindingHandlers.value.update isnt "undefined"
        ko.bindingHandlers.value.update element, valueAccessor, allBindingsAccessor, viewModel
      $(element).selectmenu("refresh", true)
      # access value
      value = valueAccessor()
      ko.unwrap(value)
  }

  ko.bindingHandlers.dragslide = {
    init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
      value = valueAccessor()
      valueUnwrapped = ko.toJS(value)
      customOptions = valueUnwrapped.options or {}
      $(element).css('overflow': 'hidden')
      # Disable selection:
      $(element).on("selectstart mousedown", (event) ->
        event.preventDefault()
      )


      showDragMessage = (target, msg) =>
        $('.drag-message')
        .text(msg)
        .css(
          top: target.position().top
          height: target.outerHeight()
          'line-height': target.outerHeight() + "px"
        ).fadeIn(500)


      lastVmouseDown = null

      dragging = no

      $(element).on("click", (event) ->
        if dragging then event.preventDefault()
        else lastVmouseDown = null
      )
      mouseDownTarget = null
      $(element).on('vmousedown', '.draggable', (event) =>
        mouseDownTarget = $(event.target).parents('.draggable')
        lastVmouseDown = event if mouseDownTarget?.length
      )

      $(element).on('vmousemove', '.draggable', (event) =>
        target = $(event.target).parents('.draggable')
        if (
          (not lastVmouseDown?) or
          (not target?.length) or
          (not mouseDownTarget?.length) or
          (mouseDownTarget[0] isnt target[0])
        )
          mouseDownTarget = null
          lastVmouseDown = null
          return

        deltaX = Math.abs(event.pageX - lastVmouseDown.pageX)
        deltaY = Math.abs(event.pageY - lastVmouseDown.pageY)
        # detect horizontal drag
        if deltaX > deltaY and deltaX > 5
          # https://code.google.com/p/android/issues/detail?id=19827
          event.preventDefault()
          event.stopPropagation()
          lastVmouseDown.preventDefault()

          
          rule = ko.dataFor(target[0])
          action = null

          startPosition = target.position()
          target.pep(
            place: false
            axis: 'x'
            shouldEase: yes
            revert: yes
            shouldPreventDefault: no
            start: (ev, obj)  => dragging = yes
            rest: (ev, obj) =>
              pepObj = target.data('plugin_pep')
              $.pep.unbind( target );
              target.attr('style', '')
              dragging = no
            drag: (ev, obj) => 
              offsetX = target.position().left - startPosition.left
              if offsetX < -120
                unless action is "deactivate"
                  showDragMessage(target, __('deactivate rule')).addClass('deactivate').removeClass('activate')
                  action = "deactivate"
              else if offsetX > 120
                unless action is "activate"
                  showDragMessage(target, __('activate rule')).addClass('activate').removeClass('deactivate')
                  action = "activate"
              else
                if action?
                  $('.drag-message').fadeOut(500)
                  action = null
              return true
            stop: (ev, obj) =>
              $('.drag-message').text('').fadeOut().removeClass('activate').removeClass('deactivate')
              if action?
                active = (action is "activate")
                pimatic.loading "saveactivate", "show", text: __(action)
                pimatic.client.rest.updateRuleByString({ruleId: rule.id, rule: {active}}).always( ->
                  pimatic.loading "saveactivate", "hide"
                ).done(ajaxShowToast).fail(ajaxAlertFail)
              target.removeClass('ui-btn-active')
          )
          # fix revert function:
          target.data('plugin_pep').revert = ->
            @moveToUsingTransforms(-@xTranslation(), 0)  if @shouldUseCSSTranslation()
            @moveTo(@initialPosition.left, 0)

          target.data('plugin_pep').handleStart(lastVmouseDown)
          lastVmouseDown = null

      )
      return
  }

)()