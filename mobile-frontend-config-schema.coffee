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
  theme:
    doc: """jQuery Mobile theme to use. If classic then jQuery Mobiles default theme is used, 
      else the graphite theme with the corresponding color theme is used.
      """
    # http://driftyco.github.io/graphite/
    format: ["classic", "aloe", "candy", "melon", "mint", "royal", "sand", "slate", "water"]
    default: 'water'
  debug:
    doc: "that to true to get additional debug outputs"
    format: Boolean
    default: false
  enabledEditing:
    doc: "enabled or disabled the drag and drop of items"
    format: Boolean
    default: true
  showAttributeVars:
    doc: "show variables for device attributes"
    format: Boolean
    default: false
  ruleItemCssClass:
    doc: "additional css classes for rule items: hideRuleName, hideRuleText"
    format: String
    default: "" # For example: "hideRuleName" or 
  rules:
    doc: "order of the rules"
    format: Array
    default: [] 