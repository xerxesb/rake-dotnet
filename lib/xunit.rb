module Rake
	class XUnitTask < TaskLib
		attr_accessor :suites_dir, :reports_dir, :options

		def initialize(params={}) # :yield: self
			@suites_dir = params[:suites_dir] || File.join(OUT_DIR, 'bin')
			@reports_dir = params[:reports_dir] || File.join(OUT_DIR, 'reports')
			@options = params[:options] || {}
			@deps = params[:deps] || []
			
			yield self if block_given?
			define
		end

		# Create the tasks defined by this task lib.
		def define
			@deps.each do |d|
				task :xunit => d
			end
			
			rule(/#{@reports_dir}\/.*Tests.*\//) do |r|
				suite = r.name.match(/.*\/(.*Tests)\//)[1]
				testsDll = File.join(@suites_dir, suite + '.dll')
				out_dir = File.join(@reports_dir, suite)
				unless File.exist?(out_dir) && uptodate?(testsDll, out_dir)
					mkdir_p(out_dir) unless File.exist?(out_dir)
					x = XUnit.new(testsDll, out_dir, nil, options=@options)
					x.run
				end
			end

			directory @reports_dir
			
			desc "Generate test reports (which ones, depends on the content of XUNIT_OPTS) inside of each directory specified, where each directory matches a test-suite name (give relative paths) (otherwise, all matching #{@suites_dir}/*Tests.*.dll) and write reports to #{@reports_dir}"
			task :xunit,[:reports] => [@reports_dir] do |t, args|
				reports_list = FileList.new("#{@suites_dir}/**/*Tests*.dll").pathmap("#{@reports_dir}/%n/")
				args.with_defaults(:reports => reports_list)
				args.reports.each do |r|
					Rake::FileTask[r].invoke
				end
			end
			
			task :xunit_clobber do
				rm_rf(@reports_dir)
			end
			
			self
		end
	end
end

class XUnit
	attr_accessor :xunit, :testDll, :reports_dir, :options
	
	def initialize(testDll, reports_dir, xunit=nil, options={})
		@xunit = xunit || File.join(TOOLS_DIR, 'xunit', 'xunit.console.exe')
		@testDll = testDll
		@reports_dir = reports_dir
		@options = options
	end
	
	def run
		sh cmd
	end
	
	def cmd
		cmd = "#{exe} #{testDll} #{html} #{xml} #{nunit} #{wait} #{noshadow} #{teamcity}"
	end
	
	def exe
		"\"#{@xunit}\""
	end
	
	def suite
		@testDll.match(/.*\/([\w\.]+)\.dll/)[1]
	end
	
	def testDll
		"\"#{@testDll}\""
	end
	
	def html
		"/html #{@reports_dir}/#{suite}.test-results.html" if @options.has_key?(:html)
	end
	
	def xml
		"/xml #{@reports_dir}/#{suite}.test-results.xml" if @options.has_key?(:xml)
	end
	
	def nunit
		"/nunit #{@reports_dir}/#{suite}.test-results.nunit.xml" if @options.has_key?(:nunit)
	end

	def wait
		'/wait' if @options.has_key?(:wait)
	end
	
	def noshadow
		'/noshadow' if @options.has_key?(:noshadow)
	end
	
	def teamcity
		'/teamcity' if @options.has_key?(:teamcity)
	end
end
