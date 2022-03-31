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
    
    property tempdir
    property source_path
    property destination_iso



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
        req = Process.run("command", args: ["-v", "#{name}"])
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

        @source_path = "#{@tempdir.to_s}/source.iso"
        # TODO: There's probably a better solution for this in the crystal community
        if  !(file_path = @source_path)
            abort("Could not open source directory to write")
        end 

        begin
            uri = URI.parse(@download_uri)
            HTTP::Client.get(uri) do |response|
                File.write(file_path, response.body_io)
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
                @source_path = flags.source
                puts "using #{flags.source} as source iso"
            else
                download_iso()
            end
        rescue ex
            abort(ex)
        end
        puts "\n"
    end

    # Extract source iso image to temp directory
    def extract_iso_image()
        Process.run("xorriso", args: ["-osirrox", "on", "-indev", "#{@source_path}", "-extract", "/", "#{@tempdir.to_s}", "&>/dev/null"])
        Process.run("chmod", args: ["-R", "u+w", "#{@tempdir.to_s}"])
        Process.run("rm", args: ["-rf", "#{@tempdir.to_s}/'[BOOT]'"])
    end

    # Add autoinstall parameter
    def add_autoinstall()
        #TODO: probably don't need a Process.run(command to do this
        Process.run("sed", args: ["-i", "-e", "'s/---/ autoinstall ---/g'", "#{tempdir.to_s}/isolinux/txt.cfg"])
        Process.run("sed", args: ["-i", "-e", "'s/---/ autoinstall ---/g'", "#{tempdir.to_s}/boot/grub/grub.cfg"])
        Process.run("sed", args: ["-i", "-e", "'s/---/ autoinstall ---/g'", "#{tempdir.to_s}/boot/grub/loopback.cfg"])
    end

    # apply all in one
    def apply_all_in_one()

        #TODO: Need to do validation on input files
        
        # create new dir in tempdir
        Dir.new("#{@tempdir.to_s}/nocloud")
        Process.run("cp", args: ["#{flags.user_data}", "#{@tempdir.to_s}/nocloud/user-data"])
        if flags.meta_data != nil
            Process.run("cp", args: ["#{flags.meta_data}", "#{@tempdir.to_s}/nocloud/meta-data"])
        else
            Process.run("touch", args: ["#{@tempdir.to_s}/nocloud/meta-data"])
        end
        
        # configure kernel command line
        Process.run("sed", args: ["-i", "-e", "'s,---, ds=nocloud;s=/cdrom/nocloud/", "---,g'", "#{tempdir.to_s}/isolinux/txt.cfg"])
        Process.run("sed", args: ["-i", "-e", "'s,---, ds=nocloud\\\;s=/cdrom/nocloud/  ---,g'", "#{tempdir.to_s}/boot/grub/grub.cfg"])
        Process.run("sed", args: ["-i", "-e", "'s,---, ds=nocloud\\\;s=/cdrom/nocloud/  ---,g'", "#{tempdir.to_s}/boot/grub/loopback.cfg"])


        stdout = IO::Memory.new
        Process.run("cat", args: ["#{tempdir.to_s}/isolinux/txt.cfg"], output: stdout)
        puts stdout.to_s

    end

    # repackage iso and write to destination
    def repackage()
        stdout = IO::Memory.new
        process = Process.run "xorriso", args: ["-as", "mkisofs", "-r", "-V", "ubuntu-autoinstall", "-J", "-b", "#{tempdir.to_s}/isolinux/isolinux.bin", "-c", "#{tempdir.to_s}/isolinux/boot.cat", "-no-emul-boot", "-boot-load-size", "4", "-isohybrid-mbr", "/usr/lib/ISOLINUX/isohdpfx.bin", "-boot-info-table", "-input-charset", "utf-8", "-eltorito-alt-boot", "-e", "#{tempdir.to_s}/boot/grub/efi.img", "-no-emul-boot", "-isohybrid-gpt-basdat", "-o", "#{destination_iso}", ".", "&>/dev/null"], output: stdout
        output = stdout.to_s
        puts output
    end


    # Entry point to build subcommand
    def run
        # Intro prints
        puts "\n\n-----------------"
        puts "Welcome to Smithr Build"
        puts "-----------------"
        puts "\n"

        # Check all Process.run(requirements
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

        # extract source
        puts "🔧 Extracting ISO image...\n"
        extract_iso_image()
        puts "👍 Extracted to #{@tempdir.to_s}"

        # add autoinstall param
        puts "🧩 Adding autoinstall parameter to kernel command line..."
        add_autoinstall()
        puts "👍 Added parameter to UEFI and BIOS kernel command lines."

        if flags.all_in_one
            puts "🧩 Adding user-data and meta-data files..."
            apply_all_in_one()
            puts "👍 Added data and configured kernel command line."
        end

        puts "📦 Repackaging extracted files into an ISO image..."

        if flags.destination != nil
            @destination_iso = flags.destination
        else
            @destination_iso = "./output.iso"
        end

        repackage()
        puts "👍 Repackaged into #{destination_iso}"

        puts "✅ Fin"

    end
end