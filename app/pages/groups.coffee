# index-page
# ----------
tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", '#groups-page', tc (event) ->

  class GroupsViewModel

    enabledEditing: ko.observable(yes)
    isSortingGroups: ko.observable(no)

    constructor: () ->
      @groups = pimatic.groups
      @hasPermission = pimatic.hasPermission

      @groupsListViewRefresh = ko.computed( tc =>
        @groups()
        @isSortingGroups()
        @enabledEditing()
        pimatic.try( => $('#groups').listview('refresh').addClass("dark-background") )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

    afterRenderGroup: (elements, group) ->
      handleHTML = $('#sortable-handle-template').text()
      $(elements).find("a").before($(handleHTML))

    toggleEditing: ->
      @enabledEditing(not @enabledEditing())

    onGroupsSorted: (group, eleBefore, eleAfter) =>
      groupOrder = []
      unless eleBefore?
        groupOrder.push group.id 
      for g in @groups()
        if g is group then continue
        groupOrder.push(g.id)
        if eleBefore? and g is eleBefore
          groupOrder.push(group.id)
      pimatic.client.rest.updateGroupOrder({groupOrder})
      .done(ajaxShowToast)
      .fail(ajaxAlertFail)
  
    onDropGroupOnTrash: (group) ->
      really = confirm(__("Do you really want to delete the %s group?", group.name()))
      if really then (doDeletion = =>
        pimatic.loading "deletegroup", "show", text: __('Saving')
        pimatic.client.rest.removeGroup(groupId: group.id)
        .always( => 
          pimatic.loading "deletegroup", "hide"
        ).done(ajaxShowToast).fail(ajaxAlertFail)
      )()

    onAddGroupClicked: ->
      jQuery.mobile.pageParams = {action: 'add'}
      return true

    onEditGroupClicked: (group) =>
      unless @hasPermission('groups', 'write') or pimatic.isDemo()
        pimatic.showToast(__("Sorry, you have no permissions to edit this group."))
        return false
      jQuery.mobile.pageParams = {action: 'update', group}
      return true

  pimatic.pages.groups = groupsPage = new GroupsViewModel()

)

$(document).on("pagecreate", '#groups-page', tc (event) ->
  groupsPage = pimatic.pages.groups
  try
    ko.applyBindings(groupsPage, $('#groups-page')[0])
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $("#groups .handle").disableSelection()
  return
)

$(document).on("pagebeforeshow", '#groups-page', tc (event) ->
  pimatic.try( => $('#groups').listview('refresh').addClass("dark-background") )
)






