# #mobile-frontend configuration options

# Defines a `node-convict` config-schema and exports it.
module.exports =
  items:
    doc: "The items to display"
    format: Array
    default: []
  mode:
    doc: "production or development mode"
    format: ["production", "development"]
    default: "production"
  debug:
    doc: "that to true to get additional debug outputs"
    format: Boolean
    default: false
  enabledEditing:
    doc: "enabled or disabled the drag and drop of items"
    format: Boolean
    default: true