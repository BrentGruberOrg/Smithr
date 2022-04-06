import cligen
import build_cmd


when isMainModule:
  
  dispatchMulti([build, help=build_cmd.help, short=build_cmd.short])

