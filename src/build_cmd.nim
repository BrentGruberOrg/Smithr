import osproc
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

# Command for building an autoinstall linux iso
proc build*(user_data="", meta_data="", allinone=false, source="", destination="output.iso"):string = 

  let requirements = @["xorriso", "sed", "curl", "gpg"]

  echo "\n\n-----------------"
  echo "Welcome to Smithr Build"
  echo "-----------------\n"

  discard validate_requirements(requirements)
  return "Hello"



