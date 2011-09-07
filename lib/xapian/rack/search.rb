#	This file is part of the "Utopia Framework" project, and is licensed under the GNU AGPLv3.
#	Copyright 2010 Samuel Williams. All rights reserved.
#	See <utopia.rb> for licensing details.

require 'uri'
require 'pathname'

require 'logger'

require 'xapian/indexer'
require 'xapian/indexer/loaders/http'
require 'xapian/indexer/extractors/html'

module Xapian
	module Rack
		
		def self.find(env, query, options = {})
			search = env['xapian.search']
			return search.find(query, options)
		end
		
		def self.get(env)
			return env['xapian.search']
		end
		
		class RelativeLoader
			def initialize(app, options = {})
				@app = app
				
				@logger = options[:logger] || Logger.new($stderr)
			end
			
			def call(name, &block)
				# Handle relative URIs
				if URI.parse(name).relative?
					env = {
						'HTTP_ACCEPT' => '*/*',
						'QUERY_STRING' => '',
						'REQUEST_METHOD' => 'GET',
						'PATH_INFO' => name,
						'rack.input' => StringIO.new,
					}
					
					begin
						status, header, content = @app.call(env)
					rescue
						@logger.error "Error requesting resource #{name}: #{$!}"
						$!.backtrace.each{|line| @logger.error(line)}
						
						yield 500, {}, nil
					end
				
					body = lambda do 
						buffer = ""
						content.each{|segment| buffer += segment}

						buffer
					end
					
					downcase_header = {}
					header.each{|k,v| downcase_header[k.downcase] = v}
					
					yield status, downcase_header, body
					
					return true
				end
				
				return false
			end
		end
		
		class Search
			def initialize(app, options = {})
				@app = app
				@database_path = options[:database]
				@database = nil
				
				unless options[:logger]
					options[:logger] = Logger.new($stderr)
					options[:logger].level = Logger::DEBUG
				end
				
				# Setup the controller
				@controller = Xapian::Indexer::Controller.new(options)
				
				@controller.loaders << RelativeLoader.new(@app)
				@controller.loaders << Xapian::Indexer::Loaders::HTTP.new(options)
				@controller.extractors['text/html'] = Xapian::Indexer::Extractors::HTML.new(options)
				
				# Setup the generator
				@generator = Xapian::TermGenerator.new()
				
				@logger = options[:logger]
				
				unless options[:indexer] == :disabled
					@indexer = Thread.new do
						while true
							begin
								@logger.info "Updating index in background..."
								index(options[:roots], options)
								@logger.info "Index update finished successfully."
							rescue
								@logger.error "Index update failed: #{$!}"
								$!.backtrace.each{|line| @logger.error(line)}
							end
							
							sleep options[:refresh] || 3600
						end
					end
				end
			end

			def find(query, options = {})
				if @database
					@database.reopen
				else
					@database = Xapian::Database.new(@database_path)
				end
				
				# Start an enquire session.
				enquire = Xapian::Enquire.new(@database)

				# Setup the query parser
				qp = Xapian::QueryParser.new()
				qp.database = @database
				query = qp.parse_query(query, options[:flags] || 0)

				enquire.query = query
				
				start = options[:start] || 0
				count = options[:count] || 10
				
				matchset = enquire.mset(start, count)
				
				return matchset
			end
			
			def index(roots, options = {})
				writable_database = Xapian::WritableDatabase.new(@database_path, Xapian::DB_CREATE_OR_OPEN)
				@logger.debug "Opening xapian database for writing: #{@database_path}"
				
				begin
					spider = Xapian::Indexer::Spider.new(writable_database, @generator, @controller)
				
					spider.add(roots)
				
					spider.process(options) do |link|
						uri = URI.parse(link)
					
						if uri.relative?
							link
						elsif options[:domains] && options[:domains].include?(uri.host)
							link
						else
							nil
						end
					end
				
					spider.remove_old!
				ensure
					@logger.debug "Closing xapian database: #{@database_path}"
					writable_database.close
				end
			end

			attr :database

			def call(env)
				env['xapian.search'] = self
				return @app.call(env)
			end
		end

	end
end
