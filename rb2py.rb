#!/usr/bin/env ruby

require 'thor'

class RubyToPythonConverter
  def initialize(ruby_code, verbose: false, debug: false)
    @ruby_code = ruby_code
    @python_lines = []
    @verbose = verbose
    @debug = debug
  end

  def convert
    lines = @ruby_code.lines
    lines.each_with_index do |line, idx|
      line.rstrip!
      converted = convert_line(line)

      if @debug
        puts "[DEBUG] Line #{idx + 1}: #{line.inspect} -> #{converted.inspect}"
      elsif @verbose
        puts "[VERBOSE] Converted: #{line.strip} ➔ #{converted.strip}"
      end

      @python_lines << converted
    end
    @python_lines.join("\n")
  end

  private

  def convert_line(line)
    case line
    when /^\s*require\s+['"](.+?)['"]/
      "import #{$1.gsub('/', '.')}"
    when /^\s*#/
      line
    when /^\s*def\s+([a-zA-Z_0-9!?=]+)/
      "def #{$1.gsub(/[!?=]/, '')}():"
    when /^\s*end\s*$/
      ""
    when /^\s*if\s+(.+)/
      "if #{translate_condition($1)}:"
    when /^\s*unless\s+(.+)/
      "if not #{translate_condition($1)}:"
    when /^\s*elsif\s+(.+)/
      "elif #{translate_condition($1)}:"
    when /^\s*else\s*$/
      "else:"
    when /^\s*begin\s*$/
      "try:"
    when /^\s*rescue\s*(\w+)?/
      err = $1 || "Exception"
      "except #{err}:"
    when /^\s*ensure\s*$/
      "# NOTE: Python 'finally:' equivalent"
    when /^\s*FileUtils\.(.+)/
      "# TODO: Translate FileUtils.#{$1}"
    when /^\s*File\.(.+)/
      "# TODO: Translate File.#{$1}"
    when /^\s*([A-Z_]+)\s*=\s*(.+)/
      "# Constant converted to variable:\n#{$1.downcase} = #{$2}"
    when /^\s*([a-zA-Z_][a-zA-Z_0-9]*)\s*=\s*(.+)/
      "#{$1} = #{translate_expression($2)}"
    when /^\s*puts\s+(.+)/
      "print(#{translate_expression($1)})"
    when /^\s*print\s+(.+)/
      "print(#{translate_expression($1)})"
    when /^\s*warn\s+(.+)/
      "print(#{translate_expression($1)}, file=sys.stderr)"
    when /^\s*exit\(?(\d*)\)?/
      code = $1.empty? ? "0" : $1
      "sys.exit(#{code})"
    else
      "# TODO: Manual translation needed: #{line}"
    end
  end

  def translate_condition(cond)
    cond.gsub('&&', 'and').gsub('||', 'or').gsub('!', 'not ')
  end

  def translate_expression(expr)
    if expr =~ /#\{.+?\}/
      expr.gsub!(/#\{(.+?)\}/, '{\1}')
      "f\"#{expr.gsub('"', '')}\""
    else
      expr
    end
  end
end

class ConverterCLI < Thor
  class_option :verbose, type: :boolean, default: false, desc: "Enable verbose output"
  class_option :debug, type: :boolean, default: false, desc: "Enable debug output (shows internal translation steps)"

  desc "convert INPUT OUTPUT", "Convert a Ruby file (INPUT) into a Python file (OUTPUT)"
  def convert(input_file, output_file)
    unless File.exist?(input_file)
      puts "Error: Input file '#{input_file}' does not exist."
      exit(1)
    end

    ruby_code = File.read(input_file)

    converter = RubyToPythonConverter.new(
      ruby_code,
      verbose: options[:verbose],
      debug: options[:debug]
    )

    python_code = converter.convert

    File.write(output_file, python_code)
    puts "✅ Successfully wrote Python code to #{output_file}"
  end

  desc "help [COMMAND]", "Describe available commands or one specific command"
  def help(*args)
    super
    puts "\nOptions:"
    puts "  --verbose    Show each conversion step"
    puts "  --debug      Show detailed internal debug information"
  end
end

ConverterCLI.start(ARGV) if __FILE__ == $0
