# Copyright 2006 Instituto de Investigaciones Dr. José María Luis Mora / 
# Instituto de Investigaciones Estéticas. 
# See COPYING.txt and LICENSE.txt for redistribution conditions.
# 
# D.R. 2006  Instituto de Investigaciones Dr. José María Luis Mora /  
# Instituto de Investigaciones Estéticas.
# Véase COPYING.txt y LICENSE.txt para los términos bajo los cuales
# se permite la redistribución.

require 'kr_logic/def_files/parser'
require 'kr_logic/def_files/interpreter'

java_import 'mx.org.pescador.server.ServerController'

module KRLogic
  module DefFiles
    
    @@logger = RJack::SLF4J[ "DefFiles" ]
  
    Parser.prepare
    @@def_files = Array.new
    @@global_index = Hash.new
  
    def DefFiles.process
      server_controller = ServerController.get_instance
      def_file_names = server_controller.def_files
  
      def_file_names.each do |full_def_file_name|
        begin      
          f = File.new(full_def_file_name,"r")
          file_contents = f.read
        ensure
          f.close
        end
        
        def_file_name = full_def_file_name.split("/")[-1] # TODO: may break on some systems
        def_file = DefFile.new(def_file_name)
        def_file.contents = Parser.parse(file_contents, def_file)
        @@def_files.push(def_file)
      end
      @@logger.info ".def files parsed"
      
      Interpreter.interpret(@@def_files)
      @@logger.info ".def files interpreted"
    end
    
    module Indexer
      def Indexer.indexed(index, cl, i)
        index[cl][i]
      end

      def Indexer.all_indexed(index, cl)
        i = index[cl]
        i ? i : []
      end

      def Indexer.count_indexed(index, cl)
        index[cl].size
      end

      def Indexer.get_index(index, cl)
        index[cl] = Array.new unless index.has_key?(cl)
        index[cl]
      end

      def Indexer.add_to_index(index, element)
        Indexer.get_index(index, element.class).push(element)
      end      
    end
    
    def DefFiles.all_elements(cl)
      Indexer.all_indexed(@@global_index, cl)
    end
    
    def DefFiles.count_elements(cl)
        Indexer.count_indexed(@@global_index, cl)
    end

    def DefFiles.add_to_global_index(element)
        Indexer.add_to_index(@@global_index, element)
    end
    
    class DefFile
      include Java::mx::org::pescador::definitionsfiles::DefFile 
      # Available from java: only the :name attribute

      attr_accessor(:name, :contents, :realm)

      def initialize(name)
        @name = name
        @index = Hash.new
#        j_bind
      end

      def element(cl, i=0)
        Indexer.indexed(@index, cl, i)
      end

      def count_elements(cl)
        Indexer.count_indexed(@index, cl)
      end

      def add_to_index(element)
        Indexer.add_to_index(@index, element)
      end

    end
    
    class DefFileContents
      attr_reader(:elements)
  
      @@allowed_contents = [Realm, DefinitionSet]
    
      def initialize(elements)
        @elements = elements 
        @elements.each do |e|
          raise "#{e.class.name} not allowed as top-level element: line #{e.line}, #{e.file}." unless (@@allowed_contents.include?(e.class))
        end
      end
    end

  end
end