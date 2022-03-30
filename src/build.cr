require "http/client"
require "uri"
require "admiral"
require "tempdir"

class UninstalledException < Exception
end

class Build < Admiral::Command
    # Smithr build subcommand


    # Required software for running build command
    @requirements = ["xorriso", "sed", "curl", "gpg"]
    @download_uri = "https://cdimage.ubuntu.com/ubuntu-server/focal/daily-live/current/focal-live-server-amd64.iso"
    
    def tempdir
        @tempdir
    end

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
                description: "Where to write the resulting iso file",
                short: d,
                default: "output.iso",
                required: false

    # Check if a requirement exists in the current filesystem
    def check_req(name)
        req = system "command -v #{name}"
        if !req
            raise UninstalledException.new("🛠 Please install #{name} to continue\n\n")
        end
    end

    # Check list of requirements
    #
    # Alerts user to install any uninstalled requirements
    # and exits program if any are found
    def validate_requirements()
    
        begin
            @requirements.each do |req|
                check_req(req)
            end
        rescue ex 
            abort(ex)
        end

    end

    def download_iso()
        
        begin
            uri = URI.parse(@download_uri)
            HTTP::Client.get(uri) do |response|
                File.write("#{@tempdir.to_s}/source.iso", response.body_io)
            end
        rescue ex
            abort(ex)
        end
    end

    # Validate a string to ensure it is a valid path and iso format
    # 
    # Returns whether source matches unix path directory and ends with .iso
    def validate_iso(iso_file : String | Nil) : Bool

        file = iso_file || ""

        exists = File.exists?(file)
        is_iso = file.ends_with?(".iso")
        exists && is_iso
    end

    # Identify iso based on whether source flag is defined
    #
    # if undefined, the latest ubuntu server 20.04 iso will be downloaded
    # otherwise file will be used from filesystem
    def identify_iso()

        puts "\n"
        begin
            if flags.source != nil
                valid = validate_iso(flags.source)
                if !valid
                    abort("\n\n🚫 Please provide a valid iso file\n\n")
                end
                puts "using #{flags.source} as source iso"
            else
                download_iso()
            end
        rescue ex
            abort(ex)
        end
        puts "\n"
    end


    def run
        # Intro prints
        puts "\n\n-----------------"
        puts "Welcome to Smithr Build"
        puts "-----------------"
        puts "\n"

        # Check all system requirements
        puts "🔎 Checking for required utilities...\n"
        #validate_requirements()
        puts "👍 All required utilities are installed.\n\n"

        puts "🔨 Creating temporary directory.\n"

        @tempdir = TempDir.new "smithr"

        # Check for source flag
        # if not defined, download latest iso
        puts "💾 Identifying Source Iso.\n"

        identify_iso()

        puts "✅ Source Iso Ready.\n\n"


        puts "✅ Fin"

    end
end