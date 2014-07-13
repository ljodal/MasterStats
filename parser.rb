require 'rubygems'
require 'bundler/setup'

require 'pp'
require 'csv'
require 'descriptive_statistics'

class Parser
  def initialize(path)
    index = {
      timestamps: [],
      captures: [],
      transfers: [],
      dmas: [],
    }

    @data = []

    # Parse file
    lines = CSV.read(path, col_sep: ';')

    # Parse headers
    headers = lines.shift
    headers.each_with_index do |h,i|
      case h
      when /^timestamp(\d+)$/
        next if $1.to_i > 2
        index[:timestamps] << i
      when /^dolphin(\d+)$/
        next if $1.to_i > 2
        index[:captures] << i
      when /^transfer(\d+)$/
        next if $1.to_i > 2
        index[:transfers] << i
      when /^dma(\d+)$/
        next if $1.to_i > 2
        index[:dmas] << i
      when /^sync/
        index[:syncer] = i
      when /^upload/
        index[:uploader] = i
        @uploader = true
      when /^bayer/
        index[:bayer] = i
      when /^hdr/
        index[:hdr] = i
      when /^stitch/
        index[:stitcher] = i
      when /^download/
        index[:downloader] = i
      when /^encode/
        index[:encoder] = i
      when /^send/
        index[:sender] = i
      when /^receive/
        index[:receiver] = i
      when /^dma/
        index[:dma] = i
      when /^num/
        index[:frame_num] = i
      when /^dropped/
        index[:dropped] = i
      else
        puts "Unknown header: "+h
      end
    end

    # Parse content
    lines.each_with_index do |cols, row|

      for i in 1...cols.length do
        next if i-1 == index[:hdr]
        diff = (cols[i].to_f - cols[i-1].to_f)
        if diff > 0.5 and diff < 1.5
          puts "Clock jump, row #{row} diff #{headers[i-1]} to #{headers[i]}: #{diff}"
          puts headers[(i-4)..i+1].map{|x| x.rjust(20)}.join(" ")
          puts lines[row-3][(i-4)..i+1].join(" ")
          puts lines[row-2][(i-4)..i+1].join(" ")
          puts lines[row-1][(i-4)..i+1].join(" ")
          puts cols[(i-4)..i+1].join(" ")
          puts lines[row+1][(i-4)..i+1].join(" ")
          puts lines[row+2][(i-4)..i+1].join(" ")
          puts lines[row+3][(i-4)..i+1].join(" ")

          for j in index[:transfers] do
            print cols[j]
            print " - "
          end
          puts ""
        end
      end

      elem = {}

      # Get all timestamps
      ts = []
      for i in index[:timestamps] do
        ts << cols[i].to_f
      end

      # Find average timestamp
      elem[:ts] = ts.mean
      elem[:ts_diff] = ts.max - ts.min

      # Find capture times
      capture = []
      for i in index[:captures] do
        capture << cols[i].to_f
      end

      elem[:capture] = capture.mean
      elem[:capture_diff] = capture.max - capture.min

      # Find transfer times
      transfer = []
      for i in index[:transfers] do
        transfer << cols[i].to_f
      end

      elem[:transfer] = transfer.mean
      elem[:transfer_diff] = transfer.max - transfer.min

      # Find dma times
      dmas = []
      for i in index[:dmas] do
        dmas << cols[i].to_f
      end

      elem[:dmas] = dmas.mean
      elem[:dmas_diff] = dmas.max - dmas.min


      elem[:sync] = cols[index[:syncer]].to_f
      elem[:upload] = cols[index[:uploader]].to_f
      elem[:bayer] = cols[index[:bayer]].to_f
      elem[:stitch] = cols[index[:stitcher]].to_f
      elem[:download] = cols[index[:downloader]].to_f
      elem[:hdr] = cols[index[:hdr]].to_f
      elem[:dma] = cols[index[:dma]].to_f
      elem[:send] = cols[index[:sender]].to_f
      elem[:receive] = cols[index[:receiver]].to_f

      elem[:encode] = cols[index[:encoder]].to_f

      elem[:dropped] = cols[index[:dropped]].to_f
      elem[:frame_num] = cols[index[:frame_num]].to_f

      #puts cols.inspect

      @data << elem
    end
  end

  def report
    methods = ["mean", "standard_deviation", "min", "max", "variance", "mode", ["percentile", 25], "median", ["percentile", 75], ["percentile", 99.9]]
    report_header(*methods)
    report_single(:ts_diff, "Timestamp difference", *methods)
    report_line(:ts, :capture, "Capture time", *methods)
    report_line(:capture, :dmas, "Transfer time", *methods)
    report_line(:dmas, :transfer, "DMA time", *methods)
    report_line(:transfer, :sync, "Sync time", *methods)
    if false
      report_line(:sync, :upload, "Upload time", *methods)
      report_line(:upload, :bayer, "Bayer time", *methods)
    else
      report_line(:sync, :bayer, "Bayer time", *methods)
    end

    if false
      report_line(:bayer, :hdr, "HDR time", *methods)
      report_line(:hdr, :stitch, "Stitch time", *methods)
    else
      report_line(:bayer, :stitch, "Stitch time", *methods)
    end
    if false
      report_line(:stitch, :download, "Download time", *methods)
      report_line(:download, :dma, "Transfer time", *methods)
    else
      report_line(:stitch, :dma, "Send time", *methods)
    end
    report_line(:dma, :send, "DMA time", *methods)
    report_line(:send, :receive, "Receive time", *methods)
    report_line(:receive, :encode, "Encode time", *methods)
    report_line(:ts, :encode, "Total time", *methods)
  end

  def agg(s1, s2, *methods)
    if methods.length > 1
      diff = diffs(s1, s2)
      methods.map{|e| diff.send(*e)}
    else
      diffs(s1, s2).send(*methods.first)
    end
  end

  def diffs(s1, s2)
    diffs = []
    for i in 1...@data.length do
      next if @data[i][:dropped] == 1 or @data[i-1][:dropped] == 1
      diff = (@data[i][s1] - @data[i][s2]).abs
      if diff > 0.75
        puts "Warn!"
        next
      end
      diffs << diff
    end
    diffs
  end

  private

  def report_header(*methods)
    print " "*21
    for m in methods do
      m = m.join("") if m.is_a? Array
      print " "+m.rjust(12)[0...12]
    end
    puts ""
  end

  def report_line(s1, s2, title, *methods)
    res = agg(s1, s2, *methods)

    print title.ljust(20, ".")
    print ":"
    for r in res do
      print " %12.4f" % (r * 1000)
    end
    puts ""
  end

  def report_single(s, title, *methods)
    times = @data.map{|e| e[s]}
    res = methods.map{|e| times.send(*e)}

    print title.ljust(20, ".")
    print ":"
    for r in res do
      print " %12.4f" % (r * 1000)
    end
    puts ""
  end
end

if $0 == __FILE__
  Parser.new(ARGV.first).report
end
