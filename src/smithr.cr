require "admiral"
require "./build.cr"

class Smithr < Admiral::Command
    # Smithr is a command line Interface for building and using linux autoinstall isos

    define_help description: "A command for building and using linux autoinstall isos"

    # Register Sub commands
    register_sub_command build : Build, description: "Build a new iso"

    # required run proc
    def run
        puts help
    end
end

Smithr.run