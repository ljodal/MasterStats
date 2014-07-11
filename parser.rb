require 'rubygems'
require 'bundler/setup'

require 'csv'
require 'descriptive_statistics'

class Parser
  def initialize(path)
    index = {
      timestamps: [],
      captures: [],
      transfers: [],
    }

    @data = []

    # Parse file
    lines = CSV.read(path, col_sep: ';')

    # Parse headers
    headers = lines.shift
    headers.each_with_index do |h,i|
      case h
      when /^timestamp\d+$/
        index[:timestamps] << i
      when /^dolphin\d+$/
        index[:captures] << i
      when /^transfer\d+$/
        index[:transfers] << i
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

      elem[:sync] = cols[index[:syncer]].to_f if index[:syncer]
      elem[:upload] = cols[index[:uploader]].to_f if index[:uploader]
      elem[:bayer] = cols[index[:bayer]].to_f if index[:bayer]
      elem[:stitch] = cols[index[:stitcher]].to_f if index[:stitcher]
      elem[:download] = cols[index[:downloader]].to_f if index[:downloader]

      elem[:encode] = cols[index[:encoder]].to_f

      #puts cols.inspect

      @data << elem
    end
  end

  def report
    methods = ["mean", "standard_deviation", "min", "max", "variance", "mode", ["percentile", 25], "median", ["percentile", 75], ["percentile", 95.3]]
    report_header(*methods)
    report_single(:ts_diff, "Timestamp difference", *methods)
    report_line(:ts, :capture, "Capture time", *methods)
    report_line(:capture, :transfer, "Transfer time", *methods)
    report_line(:transfer, :sync, "Sync time", *methods)
    if @uploader
      report_line(:sync, :upload, "Upload time", *methods)
      report_line(:upload, :bayer, "Bayer time", *methods)
    else
      report_line(:sync, :bayer, "Bayer time", *methods)
    end
    report_line(:bayer, :stitch, "Stitch time", *methods)
    report_line(:stitch, :download, "Download time", *methods)
    report_line(:download, :encode, "Encode time", *methods)
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
      diffs << (@data[i][s1] - @data[i][s2]).abs
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
