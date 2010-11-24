module Docsplit

  # Delegates to GraphicsMagick in order to convert PDF documents into
  # nicely sized images.
  class ImageExtractor

    DENSITY_ARG     = "-density 150"
    MEMORY_ARGS     = "-limit memory 256MiB -limit map 512MiB"
    DEFAULT_FORMAT  = :png

    # Extract a list of PDFs as rasterized page images, according to the
    # configuration in options.
    def extract(pdfs, options)
      @pdfs = [pdfs].flatten
      extract_options(options)
      @pdfs.each do |pdf|
        previous = nil
        @sizes.each_with_index do |size, i|
          @formats.each {|format| convert(pdf, size, format, previous) }
          previous = size if @rolling
        end
      end
    end

    # Convert a single PDF into page images at the specified size and format.
    # If `--rolling`, and we have a previous image at a larger size to work with,
    # we simply downsample that image, instead of re-rendering the entire PDF.
    # Now we generate one page at a time, a counterintuitive opimization
    # suggested by the GraphicsMagick list, that seems to work quite well.
    def convert(pdf, size, format, previous=nil)
      tempdir   = Dir.mktmpdir
      basename  = @out_file_name || File.basename(pdf, File.extname(pdf))
      directory = directory_for(size)
      pages     = @pages || '1-' + Docsplit.extract_length(pdf).to_s
      FileUtils.mkdir_p(directory) unless File.exists?(directory)
      common    = "#{MEMORY_ARGS} #{DENSITY_ARG} #{resize_arg(size)} #{quality_arg(format)}"
      if previous
        FileUtils.cp(Dir[directory_for(previous) + '/*'], directory)
        result = `MAGICK_TMPDIR=#{tempdir} OMP_NUM_THREADS=2 gm mogrify #{common} -unsharp 0x0.5+0.75 \"#{directory}/*.#{format}\" 2>&1`.chomp
        raise ExtractionFailed, result if $? != 0
      else
        page_list(pages).each do |page|
          file_name = "#{basename}.#{format}" % page
          out_file  = File.join(directory, file_name )
          cmd = "MAGICK_TMPDIR=#{tempdir} OMP_NUM_THREADS=2 gm convert +adjoin #{common} \"#{pdf}[#{page - 1}]\" \"#{out_file}\" 2>&1".chomp
          result = `#{cmd}`.chomp
          raise ExtractionFailed, result if $? != 0
        end
      end
    ensure
      FileUtils.remove_entry_secure tempdir if File.exists?(tempdir)
    end


    private

    # Extract the relevant GraphicsMagick options from the options hash.
    def extract_options(options)
      @output  = options[:output]  || '.'
      @pages   = options[:pages]
      @formats = [options[:format] || DEFAULT_FORMAT].flatten
      @sizes   = standardize_sizes(options[:size])
      @rolling = !!options[:rolling]
      @out_file_name = options[:out_file_name] # pass in a file name where %s will get replaced with the page number
      @out_dir_name  = options[:out_dir_name]  # pass in a directory name where %s will get replaced by the size
    end

    # If there's only one size requested, generate the images directly into
    # the output directory. Multiple sizes each get a directory of their own.
    def directory_for(size)
      file_name = @out_dir_name.present? ? @out_dir_name % size.name : size.name
      path = @sizes.length == 1 ? @output : File.join(@output, file_name ) 
      File.expand_path(path)
    end

    # Generate the resize argument.
    def resize_arg(size)
      return '' if size.nil?
      "-resize \"#{size.format}\""
    end
    
    # standardize the size input to an array of ImageMagickSize objects
    def standardize_sizes(sizes)
      if sizes.is_a?(Array)
        out = []
        [sizes].flatten.compact.each do |size|
          out << ImageMagickSize.new(size)
        end
      elsif sizes.is_a?(String)
        out = [ImageMagickSize.new(size)]
      else
        out = [nil] 
      end
      out
    end

    # Generate the appropriate quality argument for the image format.
    def quality_arg(format)
      case format.to_s
      when /jpe?g/ then "-quality 85"
      when /png/   then "-quality 100"
      else ""
      end
    end

    # Generate the expanded list of requested page numbers.
    def page_list(pages)
      pages.split(',').map { |range|
        if range.include?('-')
          range = range.split('-')
          Range.new(range.first.to_i, range.last.to_i).to_a.map {|n| n.to_i }
        else
          range.to_i
        end
      }.flatten.uniq.sort
    end

  end


  class ImageMagickSize
  
    attr_accessor :width, :height, :name
    
    def initialize(thing)
      
      if thing.is_a?(Hash)
        thing.symbolize_keys
        @width = thing[:width].to_s
        @height = thing[:height].to_s
        @name = thing[:name].present? ? thing[:name].to_s : @width
      elsif thing.is_a?(String)
        @name = thing
        @width = thing.split("x")[0]
        @height = thing.split("x")[1]
      end
    end
    
    def format
      [@width, @height].join("x")
    end
  end
end
