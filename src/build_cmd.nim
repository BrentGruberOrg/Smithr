import httpclient
import osproc
import std/os
import std/strformat
from std/tables import toTable


const
  help* =  { 
    "user-data": "The yaml file defining user data for cloud-init", 
    "meta-data": "The yaml file defining meta data for cloud-init",
    "allinone": "Whether to combine everything into a single iso or not",
    "source": "Source iso, if not defined will use latest ubuntu 20.04 build",
    "destination": "Where to write the resulting iso file"
  }.toTable()
  short* = { 
    "user-data": 'u', 
    "meta-data": 'm',
    "allinone": 'a',
    "source": 's',
    "destination": 'd'
  }.toTable()

type SourceNotFound = object of Exception
  
# Validate that all requirements are installed
proc validate_requirements(requirements:seq[string]):bool =
  echo "🔎 Checking for required utilities...\n"

  var uninstalled:seq[string] = @[]

  for req in requirements:
    let installed = execProcess("command", args=["-v", req], options={poUsePath})
    if installed == "":
      uninstalled.add(req)

  if uninstalled != []:
    echo "Please install the following dependencies"
    echo uninstalled
    return false

  echo "👍 All required utilities are installed.\n\n"
  return true



# Either identify iso from source flag or download the latest ubuntu server iso
proc identify_iso(source="", tempdir:string):string =
  echo "💾 Identifying Source Iso.\n"

  let download_uri:string = "https://cdimage.ubuntu.com/ubuntu-server/focal/daily-live/current/focal-live-server-amd64.iso"
  var retval:string

  #source was not defined, so download the newest iso
  if source == "":
    let source_path = &"{tempdir}/source.iso"

    var client = newHttpClient()
    downloadFile(client=client, url=download_uri, filename=source_path)

    retval = source_path
  else:
    if fileExists(source):
      retval = source
    else:
      raise newException(SourceNotFound, &"Could not find identified source iso: {source}")
      
  echo "✅ Source Iso Ready.\n\n"
  return retval

# Extract iso image
proc extract_iso_image(image_path:string, temp_dir:string):void =
  echo "🔧 Extracting ISO image...\n"
  var result = execCmdEx(&"xorriso -osirrox on -indev {image_path} -extract / {temp_dir} &>/dev/null")
  discard execCmdEx(&"chmod -R u+w {temp_dir}")
  discard execProcess(&"rm -rf {tempdir}/'[BOOT]'")
  echo "👍 Extracted to #{@tempdir.to_s}"

# Add autoinstall parameters
proc add_autoinstall_params(temp_dir:string):void =
  echo "🧩 Adding autoinstall parameter to kernel command line..."
  discard execCmdEx(&"sed -i -e 's/---/ autoinstall ---/g' {temp_dir}/isolinux/txt/cfg")
  discard execCmdEx(&"sed -i -e 's/---/ autoinstall ---/g' {temp_dir}/boot/grub/grub.cfg")
  discard execCmdEx(&"sed -i -e 's/---/ autoinstall ---/g' {temp_dir}/boot/grub/loopback.cfg")
  echo "👍 Added parameter to UEFI and BIOS kernel command lines."

# repackage the contents into a new iso
proc repackage(temp_dir:string, destination_iso:string):void = 

  echo temp_dir
  echo destination_iso

  var result = execCmdEx(&"cd {temp_dir} && xorriso -as mkisofs -r -V ubuntu-autoinstall -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -boot-info-table -input-charset utf-8 -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -o {destination_iso} .")
  echo result.output

# Command for building an autoinstall linux iso
proc build*(user_data="", meta_data="", allinone=false, source="", destination="output.iso"):string = 

  let requirements = @["xorriso", "sed", "curl", "gpg"]
  let dir = &"{getHomeDir()}.smithr"

  echo "\n\n-----------------"
  echo "Welcome to Smithr Build"
  echo "-----------------\n"

  # validate that all requirements are installed
  discard validate_requirements(requirements)

  # Create temp directory
  echo "🔨 Creating temporary directory.\n"
  try:
    discard existsOrCreateDir(dir=dir)
  except OSError as e:
    echo e.msg
    system.quit(1)

  var iso:string

  try:
    iso = identify_iso(source, dir)
  except SourceNotFound as e:
    echo e.msg
    system.quit(1)

  extract_iso_image(iso, dir)


  echo "REPACKAGING"
  repackage(dir, destination)
  echo "FINISHED"

  return "Hello"



