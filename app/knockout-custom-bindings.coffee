( ->

  # $.fn.disableSelection = ( ->
  #   @attr('unselectable', 'on')
  #     .css({
  #       '-moz-user-select':'-moz-none',
  #       '-moz-user-select':'none',
  #       '-o-user-select':'none',
  #       '-khtml-user-select':'none',
  #       '-webkit-user-select':'none',
  #       '-ms-user-select':'none',
  #       'user-select':'none'})
  #    .on('selectstart mousedown', (event) => event.preventDefault(); false )
  # )

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
        icon =  ko.unwrap(valueUnwrapped.icon)
        setIconClass($ele, icon)
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
      if valueUnwrapped
        $ele.textinput('enable'); 
      else
        $ele.textinput('disable'); 
      return
  }

  ko.bindingHandlers.jqmchecked = {
    init: ko.bindingHandlers.checked.init
    update: (element, valueAccessor) ->
      value = valueAccessor()
      valueUnwrapped = ko.unwrap(value)
      #calling 'refresh' only if already enhanced by JQM
      $(element).checkboxradio("refresh")
      return
    }


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
          $(element).find('.sortable').each((i, o) =>
            if o is parent[0] then return
            # $(o).css('background-color', 'white')
            $(o).css('margin-bottom', 0)
            $(o).css('margin-top', 0)
            #$(o).attr('style', '')
          )
          # Just for debugging
          # if eleBefore? then $(eleBefore).css('background-color', 'green')
          # if eleAfter? then $(eleAfter).css('background-color', 'red')

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
          else if eleAfter? then $(eleAfter).css('margin-top', eleHeight)
          offset = pos.top - parent.offset().top
          if offset isnt 0
            parent.data('plugin_pep').moveToUsingTransforms(0, offset)

        updateOrder = =>
          {eleBefore, eleAfter} = getElementBeforeAndAfter(parent)
          unless eleBefore is null and eleAfter is null
            sourceIndex = items.indexOf(ko.dataFor(parent[0])) 
            targetIndex = (
              if eleBefore?
                data = ko.dataFor(eleBefore)
                index = items.indexOf(data) + 1
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
              value.sorted.call(viewModel) if value.sorted

        parent.pep(
          place: false
          axis: 'y'
          shouldEase: false
          constrainTo: 'parent'
          droppable: '.droppable'
          overlapFunction: ($a, $b) =>
            rect1 = $a[0].getBoundingClientRect()
            rect2 = $b[0].getBoundingClientRect()
            drop = rect2.bottom-rect1.bottom > -20 and rect2.bottom-rect1.bottom < 10
            return drop
          start: =>
            parent.css('margin-bottom', -parent.outerHeight())
            value.isSorting(yes) if value.isSorting?
          stop: (ev, obj) =>
            onDropRegion = obj.activeDropRegions.length > 0
            $(obj.activeDropRegions).each( (i, o) =>
              value.drop.call(viewModel, ko.dataFor(parent[0]), o) if value.drop?
            )
            unless onDropRegion then updateOrder()
            pepObj = parent.data('plugin_pep')
            $.pep.unbind( parent );
            $(element).find('.sortable').attr('style', '')
            value.isSorting(no) if value.isSorting?
          drag: (ev, obj) => 
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

    update: (element, valueAccessor, allBindingsAccessor, viewModel) ->
      if typeof ko.bindingHandlers.value.update isnt "undefined"
        ko.bindingHandlers.value.update element, valueAccessor, allBindingsAccessor, viewModel
      $(element).selectmenu("refresh", true)
  }

  ko.bindingHandlers.droppable = {
    init: (element, valueAccessor, allBindings, viewModel, bindingContext) ->
      # cached vars for sorting events
      value = valueAccessor()
      valueUnwrapped = ko.toJS(value)
      customOptions = valueUnwrapped.options or {}
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
                pimatic.loading "saveactivate", "show", text: __(action)
                $.ajax("/api/rule/#{rule.id}/#{action}",
                  global: false
                ).always( ->
                  pimatic.loading "saveactivate", "hide"
                ).done(ajaxShowToast).fail(ajaxAlertFail)
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