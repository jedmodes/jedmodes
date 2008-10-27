# jedzip.rb
# 
# $Id: jedzip.rb,v 1.3 2008/10/27 17:05:21 paul Exp paul $
# 
# Copyright (c) 2008 Paul Boekholt.
# Released under the terms of the GNU GPL (version 2 or later).

require 'zip/zipfilesystem'
SLang.import_namespace "listing", "Listing"

class Zip::Jed < Zip::ZipFile
  include SLang
  include SLang::Listing
  def list
    set_readonly 0
    begin
      erase_buffer
      entries.sort.each{|f| insert(f.to_s + "\n")}
      set_buffer_modified_flag 0
      bob
    ensure
      set_readonly 1
    end
  end
  
  def view_member(filename)
    buffername = "Zip: #{filename}"
    if bufferp(buffername)[0] == 1
      pop2buf buffername
      return
    end
    pop2buf buffername
    contents = file.open(filename) {|f| f.read}
    if contents =~ /\r\n/
      contents.gsub!(/\r\n/, "\n")
      # Set CR mode
      info = getbuf_info
      info[3] |= 0x400
      setbuf_info *info
    end
    insert contents
    bob
  end
  
  def extract_member(filename, dest)
    dest = File.join(dest, File.basename(filename)) if File.directory? dest
    begin
      extract(filename, dest) {
	get_confirmation("#{dest} exists. Overwrite")
      }
    rescue Zip::ZipDestinationFileExistsError
    end
  end
end

