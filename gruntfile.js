var version = "0.6.2";

module.exports = function(grunt) {

    // Project configuration.
    grunt.initConfig({
        pkg: grunt.file.readJSON('package.json'),

        // Compile coffeescript
        coffee: {
            compileWithMaps: {
                options: {
                    sourceMap: true
                },
                files: {
                    'gaze.js': 'gaze.coffee', // 1:1 compile
                }
            }
        },

        replace: {
            example: {
                src: ['gaze.js'],
                dest: 'gaze.js',
                replacements: [{
                    from: '%%VERSION%%',
                    to: version
                    }
                ]
            }
        },

        // Minify
        uglify: {
            options: {
                banner: '/*! http://gaze.io - <%= pkg.name %> <%= grunt.template.today("yyyy-mm-dd") %> */\n'
            },

            build: {
                src: 'gaze.js',
                dest: 'gaze.min.js'
            }
        },


        // Prepare dist
        copy: {
            main: {
                files: [
                    { expand: true, src: ['gaze.*.js'], dest: 'dist/', filter: 'isFile' },

                    {
                        expand: true,
                        src: ['gaze.js'],
                        dest: 'dist/' ,
                        filter: 'isFile',
                        rename: function(dest, src) {
                            return dest + src.replace(/gaze\.js/, "gaze-" + version + ".js");
                        }
                    },

                    {
                        expand: true,
                        src: ['gaze.min.js'],
                        dest: 'dist/' ,
                        filter: 'isFile',
                        rename: function(dest, src) {
                            return dest + src.replace(/gaze\.min\.js/, "gaze-" + version + ".min.js");
                        }
                    }

                ]
            }
        },


        'ftp-deploy': {
            downloads: {
                auth: {
                    host: 'gaze.io',
                    port: 21,
                    authKey: 'xr'
                },

                src: 'dist/',
                dest: '/www.gazeio.downloads/gaze.io',
                exclusions: ['gaze.xtra.js' ]
            },

            web: {
                auth: {
                    host: 'gaze.io',
                    port: 21,
                    authKey: 'xr'
                },

                src: 'dist/',
                dest: '/www.gazeio/gaze.js',
                //exclusions: ['./.*', './node_modules/' ]
            },

        },

  });


  // Load the plugin that provides the "uglify" task.
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-ftp-deploy');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-mkdir');
  grunt.loadNpmTasks('grunt-text-replace');

  // Default task(s).
  grunt.registerTask('default', ['coffee', 'replace', 'uglify', 'copy', 'ftp-deploy']);

};
