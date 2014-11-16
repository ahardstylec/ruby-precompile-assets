# require 'thread'
# require 'digest/md5'
# require 'fileutils'
# require 'yuicompressor'
# require 'sass'
# require 'uglifier'
# require 'erb'
# require 'ruby-progressbar'

# module Wa
#     class Precompile
#         @dest="public/assets/"
#         @path="vendor/assets/"
#         @verbose=false
#         @remove_dir = false
#         @precompile_queue=Queue.new
#         @file_path_queue =[]
#         @file_queue = {}
#         @dependencie_queues = {}

#         def self.say msg
#             puts msg+"\n" if @verbose
#         end

#         def self.precompile_assets(options={})

#             @path = options[:path] if options[:path]
#             @dest = options[:dest] if options[:dest]
#             @verbose= !!options[:verbose] if options.has_key?(:verbose)
#             @remove_dir = options[:remove_dir] if options.has_key?(:remove_dir)
#             @threads_flag = options.has_key?(:threads_flag) ? options[:threads_flag] : true
#             @thread_num = options[:thread_num].is_a?(Integer) ? options[:thread_num] : 2

#             FileUtils.rm_rf @dest if @remove_dir

#             say "precompile assets in: #{@path}"

#             self.create_precompile_queue
#             progress_compile_queue = ProgressBar.create(title: "compiling assets", total: @precompile_queue.size, format: "%t: %c/%C(%p%%) <%B> %a")
#             compile_assets_proc = Proc.new do 
#                 while (file = @precompile_queue.shift(true) rescue nil) do
#                     if !File.directory?(file[:path]) || !file.nil?
#                         compile_asset(file)
#                     end
#                     progress_compile_queue.increment
#                 end
#             end


#             if @threads_flag
#                 workers=[]
#                 @thread_num.times do |n|
#                     workers << Thread.new(&compile_assets_proc) unless @precompile_queue.empty?
#                 end
#                 # wait for all threads
#                 workers.each(&:join)
#             else
#                 compile_assets_proc.call
#             end


#             self.inject_dependencies(file, dependency)
            
#             progress_compile_queue.finish
#             say "done"
#         end

#         def inject_dependencie(file_hash, dependency)
#             return unless @dependencie_queues[file[:path]].any?
#             new_file = File.read(file_hash[:dest_path])
#             @dependencie_queues[file[:path]].each do |dependency|
#                 Dir.chdir(File.basename(file_hash[:dest_path])) do
#                     new_file.gsub(/#{dependency}/, File.read(@file_queue[][:dest_path]))
#                 end
#                 File.write(file_hash[:dest_path], new_file)
#             end
#         end

#         def self.check_dependencies(file_hash)
#             return if file_hash[:changed] || !@dependencie_queues.has_key?(file_hash[:path])
            
#             self.changed = @dependencie_queues.reject do |dep| 
#                 @file_queue[dep][:changed]
#             end.any?
#         end

#         def self.search_for_dependencies(file_hash)
#             # name = file_hash[:path].gsub(/#{@path}\/|javascripts\/|stylesheets\/|images\//, '')
#             dirname = File.dirname file_hash[:path]
#             if file_hash[:original_ext] == 'js'
#                 Dir.chdir(dirname) do 
#                     file_hash[:readed].match(/\/\/=require (.*)$/) do |m|
#                         @dependencie_queues[file_hash[:path]] ||= [] #Queue.new
#                         raise "File #{$1} does not exist" unless Dir["#{$1}.*"].any?
#                         @dependencie_queues[file_hash[:path]].push($1)
#                     end
#                     file_hash[:readed].match(/\/\/=require_tree (.*)$/) do |m|
#                         raise "dir #{$1} does not exist in #{dirname}" unless File.directory?($1)
#                         Dir.glob("#{$1.chomp("/")}/**/*").each do |file|
#                             next if File.directory? file
#                             @dependencie_queues[file_hash[:path]] ||= [] #Queue.new
#                             @dependencie_queues[file_hash[:path]].push(file) unless @dependencie_queues[name].include?(file) || file.sub("./", '') == name
#                         end
#                     end
#                 end
#             end
#         end
        

#         def self.valid_asset?(file)
#             true
#         end

#         def self.create_precompile_queue
#             Dir["#{@path.chomp("/")}/**/*"].each do |file| 
#                @file_path_queue<< file if !File.directory?(file)
#             end

#             progress_path = ProgressBar.create(title: "check paths ", total: @file_path_queue.size, format: "%t: %c/%C(%p%%) <%B> %a")
            
#             @file_path_queue.each do |file|
#                 next unless self.valid_asset?(file)

#                 file_hash = {readed: File.read(file), path: file}
#                 self.parse_file_path(file_hash)

#                 self.search_for_dependencies file_hash
#                 @file_queue[file] = file_hash
#                 progress_path.increment
#             end
#             progress_dependencie = ProgressBar.create(title: "check dependencies ", total: @file_path_queue.size, format: "%t: %c/%C(%p%%) <%B> %a")

#             @file_queue.each_value do |file_hash|
#                 self.check_dependencies(file_hash)
#                 unless file_hash[:changed] && file_hash[:skip]
#                     FileUtils.rm(Dir["#{file_hash[:dest_path_filename_md5]}*"])
#                     FileUtils.rm(Dir[file_hash[:dest_path]])
#                     FileUtils.mkdir_p(file_hash[:dest_path].split("/")[0..-2].join("/"))
#                     FileUtils.touch(file_hash[:dest_path_md5])
#                     FileUtils.touch(file_hash[:dest_path])
#                     @precompile_queue.push(file_hash)
#                 end
#                 progress_dependencie.increment
#             end
#             print "\n"
#             say "file needed to compile #{@precompile_queue.size}"
#         end

#         def self.parse_file_path(file_hash)
#             file_hash[:md5]= Digest::MD5.hexdigest(file_hash[:readed])
#             file_hash[:filename_md5] = Digest::MD5.hexdigest(file_hash[:path])

#             filename_array = file_hash[:path].split('.')
#             extra_ext= nil
#             if filename_array.size > 1
#                 file_hash[:ext] =  filename_array.pop
#                 case file_hash[:ext]
#                     when /erb/
#                         file_hash[:original_ext]= filename_array.pop 
#                         case file_hash[:original_ext]
#                             when 'sass', 'scss'
#                                 file_hash[:extra_ext] = file_hash[:original_ext]
#                                 file_hash[:original_ext] = 'css'
#                             when 'coffee'
#                                 file_hash[:extra_ext] = file_hash[:original_ext]
#                                 file_hash[:original_ext] = 'js'
#                         end
#                     when /coffee/
#                         file_hash[:original_ext] = 'js'
#                     when 'scss', 'sass'
#                         file_hash[:skip] = file_hash[:path].split("/").last.chr == "_"
#                         file_hash[:original_ext] = 'css'
#                 end
#                 file_hash[:original_ext]||= file_hash[:ext]
#                 filename_array_md5 = Marshal.load( Marshal.dump(filename_array) )
#                 filename_array_md5.last<< file_hash[:filename_md5]
#                 file_hash[:dest_path_filename_md5] = filename_array_md5.join(".")
#                 filename_array_md5.last << file_hash[:md5]
#                 dest_path_for_md5 = filename_array_md5.push(file_hash[:original_ext]).join(".")
#                 dest_path = filename_array.push(file_hash[:original_ext]).join(".")
#                 file_hash[:dest_path_md5] = dest_path_for_md5.gsub(@path, "#{@dest.chomp("/")}/").gsub(/javascripts\/|stylesheets\/|images\//, '')
#                 file_hash[:dest_path] = dest_path.gsub(@path, "#{@dest.chomp("/")}/").gsub(/javascripts\/|stylesheets\/|images\//, '')
#                 file_hash[:changed] = !File.exist?(file_hash[:dest_path_md5])
#                 file_hash[:skip]||=false
#             else
#                 file_hash[:skip] = true
#             end
#         end

#         def self.compile_asset(file)
#             compile_method = case file[:ext]
#                 when 'js'
#                     :compile_js
#                 when 'coffee'
#                     :compile_coffee
#                 when 'css'
#                     :compile_css
#                 when 'sass', 'scss'
#                     :compile_sass
#                 when 'erb'
#                     :compile_erb
#                 else
#                     :compile_else 
#             end
#             self.send(compile_method, file)
#         end

#         def self.compile_js(file)
#             File.write(file[:dest_path], Uglifier.compile(file[:readed], comments: :all, mangle: true))
#         end

#         def self.compile_coffee(file)
#             file[:readed] = CoffeeScript.compile file[:readed]
#             self.compile_js(file)
#         end

#         def self.compile_css(file)
#             File.write(file[:dest_path], YUICompressor.compress_css(file[:readed]))
#         end

#         def self.compile_sass(file)
#             file[:readed] = Sass::Engine.for_file(file[:path], syntax: file[:ext].to_sym).render
#             compile_css(file)
#         end

#         def self.compile_erb(file)
#             file[:readed] = ERB.new(file[:readed]).result
#             file[:ext] = file[:extra_ext] ? file[:extra_ext] : file[:original_ext]
#             self.compile_asset(file)
#         end

#         def self.compile_else(file)
#             FileUtils.cp(file[:path], file[:dest_path])
#         end
#     end
# end

# # Wa::Precompile.precompile_assets(:remove_dir=> true, :verbose => true)