# index-page
# ----------
tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", '#rules-page', tc (event) ->

  class RulesViewModel

    enabledEditing: ko.observable(no)
    isSortingRules: ko.observable(no)

    constructor: () ->
      @rules = pimatic.rules
      @groups = pimatic.groups
      @hasPermission = pimatic.hasPermission

      data = pimatic.storage.get('pimatic.rules') or {}
      @collapsedGroups = ko.observable(data.collapsed or {})

      @rulesListViewRefresh = ko.computed( tc =>
        @rules()
        @isSortingRules()
        @enabledEditing()
        @collapsedGroups()
        g.rules() for g in @groups()
        pimatic.try( => $('#rules').listview('refresh').addClass("dark-background") )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

      @getUngroupedRules =  ko.computed( tc =>
        ungroupedRules = []
        groupedRules = []
        for g in @groups()
          groupedRules = groupedRules.concat g.rules()
        for r in @rules()
          if ko.utils.arrayIndexOf(groupedRules, r.id) is -1
            ungroupedRules.push r
        return ungroupedRules
      )

      @ruleCss = ko.computed( tc =>
        css = ""
        guiSettings = pimatic.guiSettings()
        unless guiSettings? then return css
        if guiSettings.hideRuleName
          css += " hideRuleName"
        if guiSettings.hideRuleText
          css += " hideRuleText"
        return css
      )
      pimatic.fixedAddElement(@enabledEditing, @isSortingRules, $('#add-rule'), $('#rules'))

    afterRenderRule: (elements, rule) ->
      handleHTML = $('#sortable-handle-template').text()
      $(elements).find("a").before($(handleHTML))

    toggleEditing: ->
      @enabledEditing(not @enabledEditing())

    onRulesSorted: (rule, eleBefore, eleAfter) =>

      addToGroup = (group, ruleBefore) =>
        position = (
          unless ruleBefore? then 0 
          else ko.utils.arrayIndexOf(group.rules(), ruleBefore.id) + 1
        )
        if position is -1 then position = 0
        groupId = group.id

        pimatic.client.rest.addRuleToGroup({ruleId: rule.id, groupId: groupId, position: position})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

      removeFromGroup = ( (group) =>
        groupId = group.id
        pimatic.client.rest.removeRuleFromGroup({ruleId: rule.id, groupId: groupId})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )

      updateRuleOrder = ( (ruleBefore) =>
        ruleOrder = []
        unless ruleBefore?
          ruleOrder.push rule.id 
        for r in @rules()
          if r is rule then continue
          ruleOrder.push(r.id)
          if ruleBefore? and r is ruleBefore
            ruleOrder.push(rule.id)
        pimatic.client.rest.updateRuleOrder({ruleOrder})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )

      updateGroupRuleOrder = ( (group, ruleBefore) =>
        rulesOrder = []
        unless ruleBefore?
          rulesOrder.push rule.id 
        for ruleId in group.rules()
          if ruleId is rule.id then continue
          rulesOrder.push(ruleId)
          if ruleBefore? and ruleId is ruleBefore.id
            rulesOrder.push(rule.id)
        pimatic.client.rest.updateGroup({groupId: group.id, group:{rulesOrder}})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )
      
      if eleBefore?
        if eleBefore instanceof pimatic.Rule then g1 = eleBefore.group()
        else if eleBefore instanceof pimatic.Group then g1 = eleBefore
        else g1 = null
        ruleBefore = (if eleBefore instanceof pimatic.Rule then eleBefore)
        g2 = rule.group()

        if g1 isnt g2
          if g1?
            addToGroup(g1, ruleBefore)
          else if g2?
            removeFromGroup(g2)
          else
            updateRuleOrder(ruleBefore)
        else
          if g1?
            updateGroupRuleOrder(g1, ruleBefore)
          else
            updateRuleOrder(ruleBefore)

    onDropRuleOnTrash: (rule) ->
      really = confirm(__("Do you really want to delete the %s rule?", rule.name()))
      if really then (doDeletion = =>
        pimatic.loading "deleterule", "show", text: __('Saving')
        pimatic.client.rest.removeRule(ruleId: rule.id)
        .always( => 
          pimatic.loading "deleterule", "hide"
        ).done(ajaxShowToast).fail(ajaxAlertFail)
      )()

    toggleGroup: (group) =>
      collapsed = @collapsedGroups()
      if collapsed[group.id]
        delete collapsed[group.id]
      else
        collapsed[group.id] = true
      @collapsedGroups(collapsed)
      @saveCollapseState()
      return false;

    isGroupCollapsed: (group) => @collapsedGroups()[group.id] is true

    onAddRuleClicked: ->
      jQuery.mobile.pageParams = {action: 'add'}
      return true

    onEditRuleClicked: (rule) =>
      unless @hasPermission('rules', 'write') or pimatic.isDemo()
        pimatic.showToast(__("Sorry, you have no permissions to edit this rule."))
        return false
      jQuery.mobile.pageParams = {action: 'update', rule}
      return true

    saveCollapseState: () =>
      data = pimatic.storage.get('pimatic.rules') or {}
      data.collapsed = @collapsedGroups()
      pimatic.storage.set('pimatic.rules', data)

  pimatic.pages.rules = rulesPage = new RulesViewModel()

)

$(document).on("pagecreate", '#rules-page', tc (event) ->
  rulesPage = pimatic.pages.rules
  try
    ko.applyBindings(rulesPage, $('#rules-page')[0])
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $("#rules .handle").disableSelection()
  return
)

$(document).on("pagebeforeshow", '#rules-page', tc (event) ->
  pimatic.try( => $('#rules').listview('refresh').addClass("dark-background") )
)






