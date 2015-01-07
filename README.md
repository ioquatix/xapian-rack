# Xapian::Rack

Xapian::Rack provides a rack middleware for indexing both local and external HTML documents.

## Installation

Add this line to your application's Gemfile:

	gem 'xapian-rack'

And then execute:

	$ bundle

Or install it yourself as:

	$ gem install xapian-rack

## Usage

Add the following middleware:

	use Xapian::Rack::Search,
		:database => './xapian.db'
		:roots => ['/']

The site will be indexed in the background. To perform a search:

	query = request[:query] || ""
	search = Xapian::Rack.get(request.env)
	results = Xapian::Rack.find(request.env, query, {:options => Xapian::QueryParser::FLAG_WILDCARD})
	
	# Output:
	<p>Approximately #{results.matches_estimated} results found out of #{search.database.doccount} total.</p>

	<dl class="search-results">
	<?r 
			results.matches.each do |m|
				resource = YAML::load(m.document.data)
				metadata = resource[:metadata]
	?>
		<dt><a href="#{resource[:name].to_html}">#{metadata[:title].to_html}</a> (#{m.percent}% relevance)</dt>
		<?r if metadata[:description] ?>
		<dd>#{metadata[:description].to_html}</dd>
		<dd class="href">#{URI.parse("http://www.oriontransfer.co.nz/") + resource[:name]}</dd>
		<?r end ?>
	<?r
			end
	?>
	</dl>

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

This code is dual licensed under the MIT license and GPLv3 license.

Copyright, 2015, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
