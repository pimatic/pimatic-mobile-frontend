# Grunt configuration updated to latest Grunt.  That means your minimum
# version necessary to run these tasks is Grunt 0.4.
#
# Please install this locally and install `grunt-cli` globally to run.
module.exports = (grunt) ->

  notMinified = (f) => f.indexOf('.min.') is -1
  toMin = (f) => f.replace(/\.[^\.]+$/, '.min$&')
  coffeeToJs = (f) => f.replace(/\.coffee$/, '.js')

  jsFiles = {}

  grunt.file.expand(filter: notMinified,[
    'app/*.js'
    'app/**/*.js'
  ]).forEach((f) => jsFiles[toMin f] = [f])

  coffeeFiles = {}

  grunt.file.expand([
    'app/*.coffee'
    'app/**/*.coffee'
  ]).forEach((f) => coffeeFiles["compiled/#{coffeeToJs f}"] = f)
  
  coffeeFilesToUglify = {}

  for compiled, source of coffeeFiles
    coffeeFilesToUglify[toMin coffeeToJs(source)] = compiled

  # Initialize the configuration.
  grunt.initConfig(
    coffee:
      default:
        files: coffeeFiles
    uglify:
      js:
        files: jsFiles
      coffee:
        files: coffeeFilesToUglify
  )
  # Load external Grunt task plugins.
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
 
  # Default task.
  grunt.registerTask "default", ["coffee", "uglify:coffee" , "uglify:js"]