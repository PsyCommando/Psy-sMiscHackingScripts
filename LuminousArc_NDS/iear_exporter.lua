--[[
      =====================
      IEAR Archive Dumper
      =====================
      Lua 5.2+
      2016/01/24
      psycommando@gmail.com
      
      Quick and dirty exporter for the iear archives used in the Luminous Arc games.
      Script Arguments:
        #1 - Archive path
        #2 - Output folder path
        
      For now, it assign a file name only to SWDL and SMDL files. File extensions are handed out based on the subheader of each files.
        
      --------------------------
      Consider this Public Domain, or Creative Common 0. Whichever is the most practical.
      https://creativecommons.org/publicdomain/zero/1.0/
--]]

--[[--------------------------------------------------------------------
      StrToByte
        Converts a string to a table of bytes
--]]--------------------------------------------------------------------
function StrToByte( str )
  local thebytes = {}
  local strlen = string.len(str)
  local cntstr = 1
  
  while cntstr < strlen do
    table.insert( thebytes, cntstr, string.byte(str, cntstr) )
    cntstr = cntstr + 1
  end
  
  return thebytes
end

--[[--------------------------------------------------------------------
      BytesToInt
        Converts a table of 1 to 8 bytes to a single integer
--]]--------------------------------------------------------------------
function BytesToInt( bytes, blittleendian )
  local result = 0
  
  if #bytes > 8 then
    error("Too many bytes to make a int64!")
  end
  
  if blittleendian then
    for k,v in ipairs(bytes) do
      result = bit32.bor( result, bit32.lshift( v, 8 * (k - 1) ) )
    end
  else
    for k,v in ipairs(bytes) do
      result = bit32.bor( v, bit32.lshift(result, 8) )
    end
  end
  
  return result
end

--[[--------------------------------------------------------------------
      ReadToC
        Read the table of content of the "iear" format.
--]]--------------------------------------------------------------------
function ReadToC( filehandle, toclen )
  local toc      = {}
  local magicstr = filehandle:read(4)
  
  if magicstr ~= "JTBL" then
    print("Error, JTBL not found!")
    return nil 
  end
  
  --Skip the zeroes
  filehandle:seek( "cur", 12 )

  --Iterate table
  local cntentries = 1
  
  while cntentries < (toclen+1) do
    local pointer = BytesToInt( StrToByte( filehandle:read(4) ), true )
    local len     = BytesToInt( StrToByte( filehandle:read(4) ), true )
    print("-> File #" .. cntentries .. " at off: " .. pointer .. ", len: " .. len )
    toc[cntentries] = {pointer, len}
    cntentries = cntentries + 1
  end
  
  return toc
end


--[[--------------------------------------------------------------------
      ReadSwdSmdFilename
        Read the 16 character string in a swdl or smdl file header.
--]]--------------------------------------------------------------------
function ReadSwdSmdFilename( fhndl )
  local fposbef = fhndl:seek("cur")
  fhndl:seek("cur", 32)
  local str = string.format( "%s", fhndl:read(16) )
  fhndl:seek("cur", (fposbef - fhndl:seek("cur")) )
  return str
end

--[[--------------------------------------------------------------------
      ExportEntry
        Exports to a file the content of the block
--]]--------------------------------------------------------------------
function ExportEntry( fileindex, outdir, fhndl, offset, blocklen )
  local fpath = string.format( outdir .. "/file_0x%X", offset )

  --Seek to beginning of file entry
  fhndl:seek("set",offset)
  
  --Read file extension
  local filetype = string.format( "%s", fhndl:read(4)) --string.format will removed any possible null characters
  --Read unknown number
  local unk1 = fhndl:read(4)
  --Skip the nulls
  fhndl:seek( "cur", 8 )
  
  fpath = fpath .. "." .. filetype --If the filetype isn't a SWD or SMD
  
  -- If the filetype is a SWD or SMD, we can easily fetch a decent filename instead
  if filetype == "SWD" or filetype == "SMD" then
    
    local dsename = ReadSwdSmdFilename(fhndl)
    if dsename ~= nil then  --If we didn't parse the dsename
      local dotpos = string.find( dsename, ".", 1, true)
      if dotpos ~= nil then
        fpath = outdir .. "/" .. string.sub( dsename, 1, dotpos ) .. filetype --We have a ending dot
      else
        fpath = outdir .. "/" .. dsename .. "." .. filetype --We have no ending dot!
      end
    end
    
  end

  print("* Exporting file#" .. fileindex .. " " .. fpath )
    
  --Write to file!
  local outf = io.open( fpath, "wb" )
  
  if outf == nil then
    error("Couldn't open file " .. fpath .. " for writing!")
    return nil
  end
  
  --Remove the header len from the blocklen
  blocklen = blocklen - 16
  
  --Copy - #FIXME: There's most likely a faster way to do this !
  for i=1,blocklen,1 do
    outf:write(fhndl:read(1))
  end
  
  outf:close()
  return true
end

--[[--------------------------------------------------------------------
      UnpackIear
        This unpack the iear format used in the Luminous Arc games!
--]]--------------------------------------------------------------------
function UnpackIear( filepath, outdir )
  local fhndl = io.open( filepath, "rb" )
  
  --#FIXME: Ideally replace this with something from the lfs library. Installing luad dist for lua 5.2 and etc on windows AND making it work with zerobrane studio isn't any fun..
  os.execute("mkdir \"" .. outdir .. "\"")
  
  --Parse the four character code
  readstr = fhndl:read(4)
  
  if readstr == "MAIN" then
    local toclen = BytesToInt( StrToByte( fhndl:read(4) ), true )
    fhndl:seek("cur",8) --skip the nulls
    
    print("-- Reading Table of Content --")
    local toc = ReadToC(fhndl, toclen)
    
    print("-- Unpacking Content --")
    for key,val in ipairs(toc) do
      if ExportEntry( key, outdir, fhndl, val[1], val[2] ) == nil then error("Couldn't export entry #" .. key .. "!") return nil end
    end
    
  else
    print("Error, magic number mismatch!\n")
  end

  fhndl:close()
end

--------------------------------------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------------------------------------
--UnpackIear( "C:/Users/Guill/Pokemon/RomHacks/PMDES/Workdir_Music_Research/MusicLuminousArc/Snd.iear", "C:/Users/Guill/Pokemon/RomHacks/PMDES/Workdir_Music_Research/MusicLuminousArc/out" ) 
UnpackIear( arg[1], arg[2] )