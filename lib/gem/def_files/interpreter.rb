# Copyright 2006 Instituto de Investigaciones Dr. José María Luis Mora / 
# Instituto de Investigaciones Estéticas. 
# See COPYING.txt and LICENSE.txt for redistribution conditions.
# 
# D.R. 2006  Instituto de Investigaciones Dr. José María Luis Mora /  
# Instituto de Investigaciones Estéticas.
# Véase COPYING.txt y LICENSE.txt para los términos bajo los cuales
# se permite la redistribución.

# Make certain Ruby classes storeable in Java objects
module KRLogic

  module DefFiles

    module Interpreter
     java_import 'mx.org.pescador.krmodel.KRModel'
     java_import 'mx.org.pescador.krmodel.search.Search'

      @@logger = RJack::SLF4J[ "DefFiles::Interpreter" ]
     
      def Interpreter.interpret(def_files)
#        java_import 'mx.org.pescador.krmodel.graphelements.Graph' # needed?
  
        # TODO: fix incoherency: we get the def file list as an argument but the contents of the def files
        # from static methods of the DefFiles module
        
        server_controller = ServerController.get_instance
        
        def_files.each do |def_file|
          raise "One Realm definition allowed per file" if def_file.count_elements(Realm) != 1
        end
        
        DefFiles.all_elements(Realm).each do |realm_el|
          realm_el.instantiate_first_pass
        end

        DefFiles.all_elements(Realm).each do |realm_el|
          realm_el.instantiate_second_pass
        end

        KRModel.processRealmDeps
        KRModel.checkInitialBootstrapReqs
        KRModel.generateRepository(server_controller.repositoryAbbreviation, 
          server_controller.repositoryURI)
        KRModel.generateBaseStructures

        DefFiles.all_elements(Realm).each do |realm_el|
          realm_el.instantiate_third_pass
        end
        
        ont_term_els = [ DefFiles.all_elements(Class),
                         DefFiles.all_elements(Property),
                         DefFiles.all_elements(AbstractDataType),
                         DefFiles.all_elements(FundamentalDataType),
                         DefFiles.all_elements(ComplexDataType) ].flatten
                      
        ont_term_els.each do |ont_term_el|
          ont_term_el.instantiate_first_pass
        end
        
        rule_set_els = DefFiles.all_elements(RuleSet)
        
        rule_set_els.each do |rule_set_el|
          rule_set_el.instantiate_first_pass
        end
        
        main_level_socs = KRModel.makeGroupOfMainLevelSOCs
        all_main_level_soc_members = KRModel.makeGroupOfAllMainLevelSOCMembers
                
        DefFiles.all_elements(SOC).each do |soc_el|
           soc_el.instantiate_first_pass
        end 
            
        ont_term_els.each do |ont_term_el|
          ont_term_el.instantiate_second_pass
        end

        KRModel.processOntTermHierarchy
        
        non_asbtract_data_type_els = [ DefFiles.all_elements(FundamentalDataType),
                                       DefFiles.all_elements(ComplexDataType) ].flatten
        
        non_asbtract_data_type_els.each do |non_asbtract_data_type_el|
          non_asbtract_data_type_el.instantiate_third_pass
        end
        
        # TODO: deal with rulset binding inheritance for data types

        DefFiles.all_elements(Descriptor).each do |descriptor_el|
          descriptor_el.instantiate_first_pass
        end

        DefFiles.all_elements(Descriptor).each do |descriptor_el|
          descriptor_el.instantiate_second_pass
        end

        DefFiles.all_elements(InferenceRule).each do |inf_rule_el|
          inf_rule_el.instantiate
        end
        
        DefFiles.all_elements(KRRelationRule).each do |krrr_el|
          krrr_el.instantiate_first_pass
        end

        DefFiles.all_elements(KRRelationRule).each do |krrr_el|
          krrr_el.instantiate_second_pass
        end
        
        DefFiles.all_elements(CompVectorFunction).each do |c_v_func_el|
          c_v_func_el.instantiate
        end

        DefFiles.all_elements(TextBPVFunction).each do |text_bpv_func_el|
          text_bpv_func_el.instantiate_first_pass
        end

        DefFiles.all_elements(ImageBPVFunction).each do |image_bpv_func_el|
          image_bpv_func_el.instantiate
        end
        
        DefFiles.all_elements(FullDesc).each do |full_desc_el|
          full_desc_el.instantiate
        end
        
        DefFiles.all_elements(ShortDesc).each do |short_desc_el|
          short_desc_el.instantiate
        end

        DefFiles.all_elements(TitleDesc).each do |title_desc_el|
          title_desc_el.instantiate
        end
                
        DefFiles.all_elements(VariableDesc).each do |variable_desc_el|
          variable_desc_el.instantiate
        end
        
        rule_set_els.each do |rule_set_el|
          rule_set_el.instantiate_second_pass
        end
        
        DefFiles.all_elements(Descriptions).each do |descriptions_el|
          descriptions_el.instantiate_opts
        end
        
        DefFiles.all_elements(SOC).each do |soc_el|
           soc_el.instantiate_second_pass
        end 

        # main_level_socs.setup
        all_main_level_soc_members.setup
        
        #generation of secondary-and-main rules
        if server_controller.enableSearchPaths
          
          @@logger.info("Search path generation enabled")
          
          rule_set_els.each do |rule_set_el|
            rule_set_el.instantiate_third_pass
          end
        else
          @@logger.info("Search path generation disabled")
        end
        
        DefFiles.all_elements(TextBPVFunction).each do |text_bpv_func_el|
          text_bpv_func_el.instantiate_second_pass
        end
        
        # TODO: Do another pass for datatypes to make sure needed CompVectorFuncs are implemented
      end
    end
  end
end
