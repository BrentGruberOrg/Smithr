require "admiral"

class Build < Admiral::Command
    # Build will create a new iso image based on given values
    define_help description: "Build a new autoinstall iso image"

    # user_data flag for supplying user data cloud init file
    # example:
    #   smithr build -u /path/to/file/userdata.yml
    define_flag user_data : String,
                description: "The yaml file defining user data for cloud-init",
                short: u,
                required: false

    # meta_data flag for supplying meta data cloud init file
    # example:
    #   smithr build -m /path/to/file/metadata.yml
    define_flag meta_data : String,
                description: "The yaml file defining meta data for cloud-init",
                short: m,
                required: false

    # all_in_one flag for bundling everything in a single iso
    # example:
    #   smithr build -a
    define_flag all_in_one : Bool,
                description: "Whether to combine everything into a single iso or not",
                short: a,
                default: false,
                required: false

    # source flag
    # example:
    #   smithr build -s /path/to/image/ubuntu20_04.iso
    define_flag source : String,
                description: "Source iso, if not defined will use latest ubuntu 20.04 build",
                short: s,
                required: false

    # destionation flag
    # example:
    #   smithr build -d /path/to/file/resulting_image.iso
    define_flag destination : String,
                description: "Where to write the resulting iso file"
                short: d,
                default: "output.iso"
                required: false


    def run
        puts "Hello #{flags.all_in_one || "World"}"
    end
end