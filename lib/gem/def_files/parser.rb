# Copyright 2006 Instituto de Investigaciones Dr. José María Luis Mora / 
# Instituto de Investigaciones Estéticas. 
# See COPYING.txt and LICENSE.txt for redistribution conditions.
# 
# D.R. 2006  Instituto de Investigaciones Dr. José María Luis Mora /  
# Instituto de Investigaciones Estéticas.
# Véase COPYING.txt y LICENSE.txt para los términos bajo los cuales
# se permite la redistribución.

require 'strscan'

module KRLogic
  module DefFiles
    module Parser
  
      class Token
        attr_accessor(:regex, :scan_order, :name)
        
        def initialize(regex, scan_order, name)
          @regex = regex
          @scan_order = scan_order
          @name = name.upcase + "_TOK"
        end
    
        def sym
          @name.to_sym
        end
    
        def scan_str(str_scanner)
          str_scanner.scan(@regex)
        end
      end
    
      class Rule
        attr_accessor(:code)
        attr_reader(:name)
        
        def initialize(name)
          @name = name.downcase
        end
      end
  
      # require goes here because these files need to know about the Parser class
      require 'kr_logic/def_files/base_elements'
      require 'kr_logic/def_files/standard_elements'
  
      def Parser.prepare
        server_controller = ServerController.get_instance
        grammar_location = server_controller.generated_grammar_location
        grammar_file = grammar_location + "/generated_grammar.y" 
        Element.setup_lines_and_sections      

        if server_controller.generate_grammar
          begin
            f = File.open(grammar_file, 'w')
            f << Parser.create_grammar
          rescue SystemCallError
            puts "IO error creating temporary grammar file"
            raise
          ensure
            f.close unless f.nil?
          end
    
          racc_output = `racc #{grammar_file} -o#{parser_code}`
          raise "Error processing grammar file" if ($?.exitstatus != 0)
          
        end
        
        # The following line loads autogenerated KRLogic::DefFiles::Parser::GrammarParser class
        require 'autogen_parser'
  
        @p = GrammarParser.new
      end
  
      def Parser.parse(def_file_contents, file_name)
        def_file_contents += "\n"
        ts = TokenSet.new(def_file_contents, file_name)
        @p.tokens = ts.to_a
        @p.parse
      end
  
      def Parser.create_grammar
        y = <<EOS
# Grammar for definition files
# Autogenerated from subclasses of DefFiles::Element

class KRLogic::DefFiles::Parser::GrammarParser

token
EOS
        tok_names = Element.all_tokenized_elements.map {|e|  "  " + e.token.name }
        y += tok_names.join("\n") + "\n"
        y += <<EOS

rule
  target
    : section_content { result = DefFiles::DefFileContents.new(val[0]) }
    | #{NewLine.rule.name} section_content { result = DefFiles::DefFileContents.new(val[1]) }
    ;

  section_content
    : element { result = Array.new([val[0]]) }
    | section_content element { result = val[0].push(val[1]) }
    ;

  element
EOS
        element_rule_list = Element.all_lines_and_sections.map {|e| e.rule.name }
        rules = Element.all_elements.map {|e| e.rule.code }
        y += "    : " + element_rule_list.join("\n    | ")
        y += <<EOS

    ;
    
EOS
        y += rules.join("\n")
        y += <<EOS
    
end

---- header

#require 'def_file_tokenizer'
#require 'def_file_mockup'

---- inner

  def tokens=(tokens)
    @tokens = tokens
  end
  
  def next_token
    @tokens.shift
	end

  def parse
    do_parse
  end

  def on_error(token, val, stack)
    raise "Syntax error: '\#{val[:str]}', line \#{val[:line]}, \#{val[:file].name}"
  end

---- footer

EOS
        y
      end
          
      class Tokenizer < StringScanner
            
        def initialize(str, file)
          super(str)
          @file = file
          @t_elements = Element.all_tokenized_elements
          @line = 1
        end
            
        def shift
          return [false, false] if self.eos?
          scan(/[\t ]*/)
          @t_elements.each do |e|
            if (str = e.scan_str(self))
              # TODO: fix line counting--sometimes it's off
              @line += str.scan(/\r\n|\n\r|\r|\n/).length
              return [e.token.sym, {:str=>str, :line=>@line, :file=>@file}]
            end
          end
              
          raise "Syntax error: #{self.peek(20)}, line: #{@line}, #{@file.name}."
        end
            
      end
  
      class TokenSet
        def initialize(str, file_name)
          @tokenizer = Tokenizer.new(str, file_name)
          @tokens = Array.new
          
          while true
            t = @tokenizer.shift
            @tokens.push(t) 
            break if (t[0] == false)
          end
        end
        
        def to_a
          @tokens
        end
      end
  
    end
      
  end
end