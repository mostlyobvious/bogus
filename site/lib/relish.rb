require "yaml"
require "cgi"
require "gherkin"
require "kramdown"
require "rouge"

module Relish
  FEATURES_DIR = File.expand_path("../../features", __dir__)
  NAV_FILE = File.join(FEATURES_DIR, ".nav")

  module_function

  def generate(items)
    pages.each do |page|
      items.create(page[:html], page[:attributes], page[:identifier])
    end
    items.create(syntax_stylesheet, {}, "/assets/css/syntax.css")
  end

  def nav
    @nav ||= entries.map { |entry| nav_item(entry) }
  end

  def relative(from, to)
    depth = from.split("/").reject(&:empty?).length
    depth -= 1 unless from.end_with?("/")
    path = ("../" * depth) + to.sub(%r{\A/}, "")
    path.empty? ? "./" : path
  end

  def entries
    @entries ||= YAML.safe_load(File.read(NAV_FILE)).filter_map { |e| build_entry(e) }
  end

  def build_entry(entry)
    case entry
    when String
      file, title = parse_label(entry)
      leaf(file, title)
    when Hash
      dir_label, child_labels = entry.first
      dirname, title = parse_label(dir_label)
      section(dirname, title, child_labels)
    end
  end

  def section(dirname, title, child_labels)
    children = Array(child_labels).filter_map do |label|
      file, child_title = parse_label(label)
      leaf(File.join(dirname, file), child_title)
    end
    index = File.join(FEATURES_DIR, dirname, "readme.md")
    {
      title: title || humanize(dirname),
      dir: dirname,
      source: (File.exist?(index) ? index : nil),
      children: children,
    }
  end

  def leaf(rel_path, title)
    source = File.join(FEATURES_DIR, rel_path)
    unless File.exist?(source)
      warn "Relish: skipping #{rel_path} -- listed in .nav but not found"
      return nil
    end
    {
      title: title || derive_title(source, rel_path),
      dir: page_dir(rel_path),
      source: source,
    }
  end

  def parse_label(label)
    match = label.to_s.strip.match(/\A(\S+)(?:\s+\((.+)\))?\z/)
    [match[1], match[2]]
  end

  def page_dir(rel_path)
    segments = rel_path.sub(/\.[^.]+\z/, "").split("/")
    segments.pop if segments.last == "readme"
    segments.join("/")
  end

  def url_for(dir)
    dir.empty? ? "/" : "/#{dir}/"
  end

  def path_for(dir)
    dir.empty? ? "/index.html" : "/#{dir}/index.html"
  end

  def identifier_for(dir)
    dir.empty? ? "/index.html" : "/#{dir}.html"
  end

  def derive_title(source, rel_path)
    if rel_path.end_with?(".feature")
      feature_name(source)
    else
      humanize(File.basename(rel_path, ".*"))
    end
  end

  def feature_name(source)
    line = File.foreach(source).find { |l| l =~ /^\s*Feature:/ }
    line ? line.sub(/^\s*Feature:\s*/, "").strip : humanize(File.basename(source, ".*"))
  end

  def humanize(slug)
    slug.split(/[_\s-]+/).map(&:capitalize).join(" ")
  end

  def nav_item(entry)
    item = { title: entry[:title], url: url_for(entry[:dir]) }
    item[:children] = entry[:children].map { |child| nav_item(child) } if entry[:children]&.any?
    item
  end

  def pages
    entries.flat_map do |entry|
      [page_for(entry), *Array(entry[:children]).map { |child| page_for(child) }]
    end
  end

  def page_for(entry)
    dir = entry[:dir]
    url = url_for(dir)
    {
      identifier: identifier_for(dir),
      html: render_page(entry, url),
      attributes: { title: entry[:title], url: url, path: path_for(dir) },
    }
  end

  def render_page(entry, url)
    html = +render_source(entry)
    html << child_index(entry[:children], url) if entry[:children]&.any?
    html
  end

  def render_source(entry)
    source = entry[:source]
    return %(<article class="prose"><h1>#{escape(entry[:title])}</h1></article>) if source.nil?

    if source.end_with?(".feature")
      render_feature(File.read(source))
    else
      render_markdown(File.read(source), entry[:title])
    end
  end

  def render_markdown(text, title)
    heading = text.lstrip.start_with?("# ") ? "" : %(<h1>#{escape(title)}</h1>)
    %(<article class="prose">#{heading}#{markdown(text)}</article>)
  end

  def markdown(text)
    Kramdown::Document.new(text).to_html
  end

  def render_feature(source)
    document = parse_feature(source)
    return %(<article class="prose"><pre>#{escape(source)}</pre></article>) unless document

    feature = document.feature
    out = +%(<article class="feature">)
    out << %(<h1>#{escape(feature.name)}</h1>)
    description = dedent(feature.description.to_s)
    out << %(<div class="feature-description">#{markdown(description)}</div>) unless description.strip.empty?
    feature.children.each { |child| out << render_child(child) }
    out << %(</article>)
    out
  end

  def render_child(child)
    node = child.background || child.scenario
    return "" unless node

    background = !child.background.nil?
    out = +%(<section class="scenario#{background ? " background" : ""}">)
    if background
      out << %(<h2 class="scenario-heading"><span class="keyword">#{escape(node.keyword)}</span></h2>)
    else
      out << %(<h2 class="scenario-heading"><span class="keyword">#{escape(node.keyword)}:</span> #{escape(node.name)}</h2>)
    end
    description = dedent(node.description.to_s)
    out << %(<div class="scenario-description">#{markdown(description)}</div>) unless description.strip.empty?
    out << %(<ol class="steps">)
    node.steps.each { |step| out << render_step(step) }
    out << %(</ol></section>)
    out
  end

  def render_step(step)
    out = +%(<li class="step">)
    out << %(<span class="step-keyword">#{escape(step.keyword.strip)}</span> )
    out << %(<span class="step-text">#{escape(step.text)}</span>)
    out << render_doc_string(step.doc_string) if step.doc_string
    out << render_data_table(step.data_table) if step.data_table
    out << %(</li>)
    out
  end

  def render_doc_string(doc_string)
    content = doc_string.content.to_s
    if doc_string.media_type.to_s.downcase == "ruby"
      highlight(content)
    else
      %(<pre class="doc-string"><code>#{escape(content)}</code></pre>)
    end
  end

  def render_data_table(table)
    rows = table.rows.map do |row|
      %(<tr>#{row.cells.map { |cell| %(<td>#{escape(cell.value)}</td>) }.join}</tr>)
    end.join
    %(<table class="data-table"><tbody>#{rows}</tbody></table>)
  end

  def highlight(code)
    formatter = Rouge::Formatters::HTML.new
    lexer = Rouge::Lexers::Ruby.new
    %(<div class="highlight"><pre><code>#{formatter.format(lexer.lex(code))}</code></pre></div>)
  end

  def child_index(children, from_url)
    items = children.map do |child|
      href = relative(from_url, url_for(child[:dir]))
      %(<li><a href="#{href}">#{escape(child[:title])}</a></li>)
    end.join
    %(<nav class="section-children"><h2>In this section</h2><ul>#{items}</ul></nav>)
  end

  def syntax_stylesheet
    light = Rouge::Themes::Github.mode(:light).render(scope: ".highlight")
    dark = Rouge::Themes::Github.mode(:dark).render(scope: ".highlight")
    "#{light}\n@media (prefers-color-scheme: dark) {\n#{dark}\n}\n"
  end

  def parse_feature(source)
    Gherkin
      .from_source("feature", source, { include_gherkin_document: true })
      .find(&:gherkin_document)
      &.gherkin_document
  rescue StandardError => e
    warn "Relish: could not parse feature: #{e.message}"
    nil
  end

  def dedent(text)
    lines = text.split("\n", -1)
    indents = lines.reject { |line| line.strip.empty? }.map { |line| line[/\A */].length }
    return text if indents.empty?

    margin = indents.min
    lines.map { |line| line[margin..] || "" }.join("\n")
  end

  def escape(text)
    CGI.escapeHTML(text.to_s)
  end
end
