# Copyright 2006 Instituto de Investigaciones Dr. José María Luis Mora / 
# Instituto de Investigaciones Estéticas. 
# See COPYING.txt and LICENSE.txt for redistribution conditions.
# 
# D.R. 2006  Instituto de Investigaciones Dr. José María Luis Mora /  
# Instituto de Investigaciones Estéticas.
# Véase COPYING.txt y LICENSE.txt para los términos bajo los cuales
# se permite la redistribución.

module KRLogic
  module DefFiles
  
    java_import 'mx.org.pescador.server.ServerController'
    
    class Element; end
    class Section < Element; end
    class Line < Element; end
    
    class Element
      # the following comment may no longer hold, leavning for now
      ## Subclasses may create a Java interface which must extend the
      ## Java interface mx.org.pescador.definitionsfile.DefFileElement.
      ## Methods offered to Java from this superclass are:
      ## origStr, line and inFile

      include Java::MxOrgPescadorDefinitionsfiles::DefFileElement
      
      server_controller = ServerController.get_instance
      @@logger = RJack::SLF4J[ "DefFiles::Element" ]
      
      attr_accessor(:file, :line, :orig_str)
      alias_method(:origStr, :orig_str)

      @@all_elements = Array.new
      @@all_organized = false

      def logger
        @@logger
      end
                
      def Element.token
        @token
      end
      
      def Element.rule
        @rule
      end
      
      def Element.name
        @name
      end
  
      def Element.name=(name)
        @scan_for_str = name
        @name = self.unique_name(name)
      end
  
      def Element.regexp_for_val=(rfv)
        @regexp_for_val = rfv
      end
      
      def Element.regexp_for_val
        @regexp_for_val
      end
  
      def Element.make_token(regex, scan_order)
        tok_name = @name
        @token = Parser::Token.new(regex, scan_order, tok_name)
      end
  
      def Element.make_standard_token
        self.make_token(Regexp.new("\\b" + @scan_for_str + "\\b"), 100)
      end
  
      def Element.uses_token?
        if @token
          true
        else
          false
        end
      end
  
      def Element.make_index=(bool)
        @make_index = bool
      end
      
      def Element.make_index?
        if @make_index
          true
        else
          false
        end
      end
  
      def Element.scan_str(str_scanner)
        if @token
          s = @token.scan_str(str_scanner)
          if s
            s
          else
            nil
          end
        else
          nil
        end
      end
      
      def Element.setup
        @rule = Parser::Rule.new(@name)
        @@all_organized = false
      end
      
      def Element.setup_lines_and_sections
        Element.all_lines_and_sections.each do |e|
          e.setup
        end
      end
      
      def Element.all_elements
        self.organize_elements unless @@all_organized
        @@all_elements
      end
        
      def Element.all_tokenized_elements
        self.organize_elements unless @@all_organized
        @@all_tokened_elements
      end
      
      def Element.all_lines_and_sections
        self.organize_elements unless @@all_organized
        @@all_lines_and_sections
      end
      
      def initialize(args)
        @orig_str = args[:str]
        @line = args[:line]
        @file = args[:file]

        if (self.class.make_index?)
          @file.add_to_index(self) 
          DefFiles.add_to_global_index(self)
        end

        @done = false
#        j_bind if self.class.j_has_interface?
      end
      
      def done?
        @done
      end
      
      def done
        @done = true
      end
      
      def inFile
        # former comments and code from when RJB was used
        # this method is meant to be called only from Java
        # Returns the JavaBridge representation of the file
        # @file.j
        return @file
      end
      
      private
  
      def Element.add_to_list(e)
        @@all_elements.push(e)
        @@all_organized = false
        e.instance_variable_set(:@token, nil)
      end
  
      def Element.unique_name(name)
        test_name = name.downcase
        list = (self.all_elements.map{|e| e.name ? e.name.downcase : nil }).compact
        if list.include?(test_name)
          ctr = 0
          while list.include?(test_name)
            test_name = name.downcase + "_" + (++ctr).to_s
          end
          name + "_" + ctr.to_s
        else
          name
        end
      end
        
      def Element.organize_elements
        @@all_elements.sort! do |e1, e2|
          ord1 = (e1.uses_token? ? e1.token.scan_order : 10000)
          ord2 = (e2.uses_token? ? e2.token.scan_order : 10000)
          ord1 <=> ord2
        end
        @@all_tokened_elements = @@all_elements.reject do |e|
          not e.uses_token?
        end
        @@all_lines_and_sections = @@all_elements.reject do |e| 
          (e.superclass != Line) && (e.superclass != Section)
        end
        @@all_organized = true
      end
    end
  
  # Snippets
  
    # TODO: Add as class methods some code that is repeated in various Snippet rules
    class Snippet < Element
      attr_accessor(:val)
    
      def Snippet.make_standard_rule
        @rule = Parser::Rule.new(@name)
        @rule.code = <<EOS
  #{@rule.name}
    : #{@token.name} { result = #{self.to_s}.new(val[0]) }
    ;
EOS
      end
  
      def Snippet.inherited(el)
        Element.add_to_list(el)
      end
  
      def initialize(args)
        super(args)
        @val = @orig_str.slice(self.class.regexp_for_val, 1) if (self.class.regexp_for_val)
      end
    end
  
    class QuotedText < Snippet
      self.name = "QuotedText" 
      self.make_token(/".*?"/u, 1)
      self.regexp_for_val = /"(.*?)"/u
      self.setup
      self.make_standard_rule
    end
    
    class LanguageTag < Snippet
      self.name = "LanguageTag"
      self.make_token(/@[a-z]{2,2}\b/, 500)
      self.regexp_for_val = /([a-z]{2,2})/
      self.setup
      self.make_standard_rule
    end
  
    class DefaultStr < Snippet
      self.name = "DefaultStr"
      self.make_token(/\bdefault\b/, 700)
      self.setup
      self.make_standard_rule
    end
  
    class FromPropRangeStr < Snippet
      self.name = "FromPropRangeStr"
      self.make_token(/\bfromPropRange\b/, 700)
      self.setup
      self.make_standard_rule
    end

    class CaptureSearchHits < Snippet
      self.name = "CaptureSearchHits"
      self.make_token(/\bcaptureSearchHits\b/, 700)
      self.setup
      self.make_standard_rule
    end
    
    class ValueStr < Snippet
      self.name = "ValueStr"
      self.make_token(/\bVALUE\b/, 700)
      self.setup
      self.make_standard_rule
    end

    class CodeBlock < Snippet
      self.name = "CodeBlock"
      self.make_token(/\|\{.*?\}\|/mu, 1901)
      self.regexp_for_val = /\|\{(.*)\}\|/mu
      self.setup
      self.make_standard_rule
    end
  
    class CodeInDescTemplate < Snippet
      self.name = "CodeInDescTemplate"
      self.make_token(/\<\%.*?\%\>/mu, 1000)
      self.regexp_for_val = /\<\%(.*)\%\>/mu
      self.setup
      self.make_standard_rule
    end
  
    class URI < Snippet
      self.name = "URI"
      self.make_token(/\b[a-zA-Z_]\w*:\w+/u, 1903)
      self.regexp_for_val = /(.*)/
      self.setup
      self.make_standard_rule
      
      attr_reader(:prefix, :localURIPart)
      
      def initialize(args)
        # this goes here because we can't initialize this Java class when this Ruby class 
        # is first read in
        java_import 'mx.org.pescador.krmodel.graphelements.Graph' 
        
        super(args)
        parse_result = Graph.parsePrettyURI(@val)
        @prefix = parse_result.prefix
        @localURIPart = parse_result.localURIPart
      end
      
    end
  
    class Integer < Snippet
      self.name = "Integer"
      self.make_token(/\b\d+\b/, 1904)
      self.regexp_for_val = /(.*)/
      self.setup
      self.make_standard_rule
    end
  
    class Identifier < Snippet
      self.name = "Identifier"
      self.make_token(/\b[a-zA-Z_](\w|\.)*/u, 2000)
      self.regexp_for_val = /(.*)/
      self.setup
      self.make_standard_rule
      
      def initialize(args)
        super(args)
      end
    end
  
    class KROperator < Snippet
      self.name = "KROperator"
      self.make_token(/-\>/, 1903)
      self.setup
      self.make_standard_rule
    end

    class KRRelRefOptions < Snippet
      self.name = "KRRelRefOptions"
      self.make_token(/\[(inv|nonInf)(, +(inv|nonInf))*?\]/, 1903)
      self.setup
      self.make_standard_rule

      attr_reader(:inv, :non_inf)

    def initialize(args)
      super(args)
      @inv = @orig_str.match(/\binv\b/) ? true : false
      @non_inf = @orig_str.match(/\bnonInf\b/) ? true : false
    end
    
    end

    class KRRelRefPartWithOptions  < Snippet
      self.name = "KRRelRefPartWithOptions"
      self.setup
      @rule.code = <<EOS
  #{@rule.name}
    : #{Identifier.rule.name} #{KRRelRefOptions.rule.name}
        { result = #{self.to_s}.new({ :str =>val[0..1].map{|arg| arg.orig_str}.join(' '),
          :line=>val[0].line,
          :file=>val[0].file });
          result.id = val[0]; 
          result.inv = val[1].inv; result.non_inf = val[1].non_inf}
EOS
    
      attr_accessor(:id, :inv, :non_inf)

    end
  
    class LinkingKRRelRef < Snippet
      self.name = "LinkingKRRelRef"
      self.setup
      @rule.code = <<EOS
  #{@rule.name}
    : #{@rule.name} #{KROperator.rule.name} #{Identifier.rule.name}
        { result = val[0]; 
          result.val.push(val[2]);
          result.orig_str = "\#{result.orig_str} \#{val[1].orig_str} \#{val[2].orig_str}" }
    |  #{@rule.name} #{KROperator.rule.name} #{KRRelRefPartWithOptions.rule.name}
        { result = val[0]; 
          result.val.push(val[2]);
          result.orig_str = "\#{result.orig_str} \#{val[1].orig_str} \#{val[2].orig_str}" }
    | #{Identifier.rule.name} #{KROperator.rule.name} #{Identifier.rule.name} 
        { result = #{self.to_s}.new({ :str =>val[0..-1].map{|arg| arg.orig_str}.join(' '),
          :line=>val[0].line,
          :file=>val[0].file });
          result.val=[val[0], val[2]] }
    | #{Identifier.rule.name} #{KROperator.rule.name} #{KRRelRefPartWithOptions.rule.name} 
        { result = #{self.to_s}.new({ :str =>val[0..-1].map{|arg| arg.orig_str}.join(' '),
          :line=>val[0].line,
          :file=>val[0].file });
          result.val=[val[0], val[2]] }
    | #{KRRelRefPartWithOptions.rule.name} #{KROperator.rule.name} #{Identifier.rule.name} 
        { result = #{self.to_s}.new({ :str =>val[0..-1].map{|arg| arg.orig_str}.join(' '),
          :line=>val[0].line,
          :file=>val[0].file });
          result.val=[val[0], val[2]] }
    | #{KRRelRefPartWithOptions.rule.name} #{KROperator.rule.name} #{KRRelRefPartWithOptions.rule.name} 
        { result = #{self.to_s}.new({ :str =>val[0..-1].map{|arg| arg.orig_str}.join(' '),
          :line=>val[0].line,
          :file=>val[0].file });
          result.val=[val[0], val[2]] }
    ;
EOS
    end
  
    class NewLine < Snippet
      self.name = "NewLine"
      self.make_token(/(\#.*?)*(\r\n|\n\r|\r|\n)+/, 1004)
      self.setup
      @rule.code = <<EOS
  #{@rule.name}
    : #{@token.name}
    | #{@rule.name} #{@token.name}
    ;
EOS
    end
  
    class StartTagStart < Snippet
      self.name = "StartTagStart"
      self.make_token(/</, 1002)
      self.setup
      self.make_standard_rule
    end
  
    class EndTagStart < Snippet
      self.name = "EndTagStart"
      self.make_token(/<\//, 1001)
      self.setup
      self.make_standard_rule
    end
  
    class TagEnd < Snippet
      self.name = "TagEnd"
      self.make_token(/>/, 1003)
      self.setup
      self.make_standard_rule
    end
  
    class Section < Element
      attr_accessor(:is_in, :index)
      attr_reader(:contents, :id)
      
      # Instance methods
      
      def add_contents(contents)
        @contents = contents
        @cont_index = Hash.new
        @contents.each_index do |i|
          e = @contents[i]
          cls = e.class
          raise "#{cls.name} not allowed in #{self.class.name}: line #{@line}, #{@file}." unless (self.class.allowed_contents.include?(e.class))
          e.is_in = self
          e.index = i
          if @cont_index.has_key?(cls)
            @cont_index[cls].push(e)
          else
            @cont_index[cls] = [e]
          end
        end
      end

      def contained(cls, index=0)
        if @cont_index.has_key?(cls)
          @cont_index[cls][index]
        else
          nil
        end
      end

      def count_contained(cls)
        if @cont_index.has_key?(cls)
          @cont_index[cls].size
        else
          0
        end
      end

      def all_contained(cls)
        i = @cont_index[cls]
        i ? i : []
      end

      def set_id(id)
        @id = id
      end
    
      # Class methods
      
      def Section.make_standard_name
        n = self.to_s.slice(/\w+$/)
        n[0,1] = n[0,1].upcase
        self.name=(n)
      end
      
      def Section.section_id_opts
        @section_id_opts
      end
  
      def Section.section_id_opts=(opts)
        @section_id_opts = opts
      end
  
      def Section.setup
        self.make_standard_name unless @name
        super
        self.make_standard_token
        self.make_rule
      end
  
      def Section.allowed_contents
        @allowed_contents
      end
      
      def Section.allowed_contents=(allowed)
        @allowed_contents = allowed
      end
  
      def Section.make_rule
        @rule = Parser::Rule.new(@name)
        sts = StartTagStart.rule.name
        ets = EndTagStart.rule.name
        te = TagEnd.rule.name
        nl = NewLine.rule.name
        rule_code_bits = Array.new
        
        @section_id_opts.each do |opt|
          if opt
            id = opt.rule.name
            rule_code_bit = "#{sts} #{@token.name} #{id} #{te} #{nl} section_content #{ets} #{@token.name} #{te} #{nl} { result = #{self.to_s}.new(val[1]); result.set_id(val[2]); result.add_contents(val[5]) }"
          else
            rule_code_bit = "#{sts} #{@token.name} #{te} #{nl} section_content #{ets} #{@token.name} #{te} #{nl} { result = #{self.to_s}.new(val[1]); result.add_contents(val[4]) }"
          end
          rule_code_bits.push(rule_code_bit)
        end
  
        @rule.code =  <<EOS
  #{@rule.name}
    : #{rule_code_bits.join("\n    | ")}
    ;
EOS
      end
      
      def Section.inherited(el)
        Element.add_to_list(el)
      end
    end
  
    class Line < Element
      attr_accessor(:args, :is_in, :index)
  
      @arg_opts = Array.new
      @implied_directive = false
      @directive_same_token_as = nil
  
      def Line.make_standard_name
        n = self.to_s.slice(/\w+$/)
        n[0,1] = n[0,1].downcase
        self.name=(n)
      end
  
      def Line.arg_opts
        @arg_opts
      end
      
      def Line.arg_opts=(arg_opts)
        @arg_opts = arg_opts
      end
  
      def Line.implied_directive
        @implied_directive
      end
  
      def Line.implied_directive=(id)
        @implied_directive = id
      end
  
      def Line.directive_same_token_as
        @directive_same_token_as
      end
  
      def Line.directive_same_token_as=(dsta)
        @directive_same_token_as = dsta
      end
  
      def Line.setup
        self.make_standard_name unless @name
        super
        self.make_standard_token unless @implied_directive
        self.make_rule
      end
  
      def Line.make_rule
        @rule = Parser::Rule.new(@name)
        nl = NewLine.rule.name
        rule_code_bits = Array.new
  
        if @directive_same_token_as
          token_bit = "#{@directive_same_token_as.token.name}"
        elsif (not @implied_directive)
          token_bit = "#{@token.name}"
        end
        
        @arg_opts.each do |opt|
          if opt.length > 0
            args_code_bit = (opt.map {|arg| arg.rule.name }).join(" ")
            if @implied_directive
              rule_code_bit = <<EOS.chomp("\n")
#{args_code_bit} #{nl} { result = #{self.to_s}.new({ :str =>val[0..-2].map{|arg| arg.orig_str}.join(' '),
          :line=>val[0].line,
          :file=>val[0].file }); 
        result.args = val[0..-2] }
EOS
            else
              rule_code_bit = "#{token_bit} #{args_code_bit} #{nl} { result = #{self.to_s}.new(val[0]); result.args = val[1..-2] }"
            end
          else          
            if @implied_directive
              raise "Attempt to define element with implied directive but no arguments: #{self.to_s}"
            else      
              rule_code_bit = "#{token_bit} #{nl} { result = #{self.to_s}.new(val[0]) }"
            end
          end
          rule_code_bits.push(rule_code_bit)
        end
  
        @rule.code =  <<EOS
  #{@rule.name}
    : #{rule_code_bits.join("\n    | ")}
    ;
EOS
      end
  
      def Line.inherited(el)
        Element.add_to_list(el)
      end
    end
    
  end
end
