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

    # TODO: Implement full standardized error reporting mechanism from both Ruby and Java
  
    # Mixins for procedures used here and there repeatedly

    module MultiStringCreation
      java_import 'mx.org.pescador.Lang'
    
      def add_to_multi_string(lang_alt)
        text = args[0].val
        lang = Lang.get(args[1].val)
        lang_alt.addString(text, lang)
      end
      
      def add_all_to_multi_string(lang_alt, elements)
        elements.each do |e| 
          e.add_to_multi_string(lang_alt)
          e.done
        end
      end
      
    end

    module NameAndComment
      include MultiStringCreation
      
      def add_name_and_comment(kr_model_obj)
        name = kr_model_obj.name
        add_all_to_multi_string(name, all_contained(MultilingualText))
        comment = kr_model_obj.comment
        add_all_to_multi_string(comment, all_contained(Comment))
      end
      
    end
        
    module OntTerm
      include NameAndComment
      
      def instantiate_first_pass
        # TODO: check that the term's prefix is indeed the same as that of this realm
        @realm = @file.realm
        hardcoded = contained(Hardcoded)
        if hardcoded
          @ont_term = get_existing_term
          hardcoded.done
        else
          @ont_term = generate_term
        end
        @ont_term.setDefFileElement(self)
        add_name_and_comment(@ont_term)
      end
      
    end

    module DataType
      include OntTerm
      java_import 'mx.org.pescador.krmodel.graphelements.Graph'
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'

      def add_sub_data_types
        all_contained(SubDataTypeOf).each do |e|
          graph_part = @realm.getGraphPart(e.prefix)
          data_type = Graph.getDataType(e.localURIPart, graph_part)
          @ont_term.addSubDataTypeOf(data_type)
          e.done
        end
      end
      
      def add_comp_vectors
        all_contained(ComparisonVector).each do |e|
          # TODO: check for attempts to add more than one default
          RuleManager.generateCompVector( e.ident,
                                          e.return_class,
                                          @ont_term,
                                          e.is_default,
                                          e.j_def_file_el )
          e.done
        end
      end

      def add_unorderable
        if(contained(UnOrderable))
          @ont_term.setUnOrderable(true)
        else
          @ont_term.setUnOrderable(false)
        end
      end

      def add_groupable
        if(contained(Groupable))
          @ont_term.setGroupable(true)
        else
          @ont_term.setGroupable(false)
        end
      end
      
      def instantiate_second_pass
        add_sub_data_types
        add_comp_vectors
        add_unorderable
        add_groupable
        @ont_term.writeData
      end

      # TODO: sub-module for non-abstract data types only, with this function and
      # instantiate_third_pass

      def set_rule_set_for_values
        count = count_contained(BindToRuleSet)
        if (count > 1)
          raise "Current implementation allows only one bindToRuleSet directive for each ComplexDataType and FundamentalDataType: " + @ont_term.localURIPart
        elsif (count == 1)
          bind_to_rs = contained(BindToRuleSet)
          rs = RuleManager.getRuleSet(bind_to_rs.ident, @realm)
          @ont_term.setRSForValues(rs)
          bind_to_rs.done
        else
          logger.info("Non-Abstract Data Type with unbound values: " + @id.val)
        end
      end

    end
    
    module FirstArgIsURI
      def prefix
        args[0].prefix
      end
      
      def localURIPart
        args[0].localURIPart
      end
    end

    module FirstArgIsIdentifierAndActsAsVal
      def val
        args[0].val
      end
    end

    module InWrapperInRuleSet
      def rule_set
        is_in.is_in.rule_set
      end
    end

    module UniqueId
      def u_ident(rule_set)
        letters = { ?v => 'aeiou',
	                ?c => 'bcdfghjklmnprstvwyz' }
	    word = ''
	    'cvcvcvc'.each_byte do |x|
	     source = letters[x]
	     word << source[rand(source.length)].chr
	    end
	    word = rule_set.ident + '_' + word
	   return word
      end
    end
    
    # Various
  
    class MultilingualText < Line    
      self.arg_opts = [[QuotedText, LanguageTag]]
      self.implied_directive = true
      include MultiStringCreation
    end
      
    class Comment < Line    
      self.arg_opts = [[QuotedText, LanguageTag]]
      include MultiStringCreation
    end

    class SearchWeight < Line
      self.arg_opts = [[Integer]]
      
      def val
        args[0].val
      end
    end

    class AdjPhraseRule < Line    
      self.arg_opts = [[Identifier, QuotedText, Identifier],
                       [Identifier, QuotedText, Identifier, Identifier],
                       [Identifier, QuotedText, Identifier, Identifier, Identifier]]
      
      java_import 'mx.org.pescador.Lang'
      java_import 'mx.org.pescador.krmodel.search.AdjPhraseRuleType'
      java_import 'mx.org.pescador.krmodel.search.AdjPhraseRule'
      java_import 'mx.org.pescador.krmodel.search.SpanishGender'
      
      # First argument is language tag
      # Second is this string
      # Third is the type of AdjPhraseRule
      # Fourth, optional arg is gender of the surface tail (M or F)
      # Fifth, optional arg is number of the surface tail (S, P or Inter)
      
      def instantiate
        
        lang = Lang.get(args[0].val)
        if (args[0].val != "es")
          raise "adj phrase rules only available for Spanish for the time being"
        end

        type = nil
        case args[2].val
          when "tailReferringTerm"
            type = AdjPhraseRuleType::TAIL_REFERRING_TERM
          when "tailSearchTerm"
            type = AdjPhraseRuleType::TAIL_SEARCH_TERM
          when "chaining"
            type = AdjPhraseRuleType::CHAINING
          else
            raise "Error in type of adj phrase specification"
        end
        @rule = AdjPhraseRule.new(type, lang)
        
        @rule.setTextTemplate(args[1].val)
        
        if (args[3])
          surface_tail_gender = nil
          case args[3].val
            when "M"
              surface_tail_gender = SpanishGender::MASCULINE
            when "F"
              surface_tail_gender = SpanishGender::FEMININE
            else
              raise "Error in surface tail gender desigantion for adj phrase"
          end
          @rule.setSurfaceTailGender(surface_tail_gender)
        end
        
        if (args[4])
          case args[4].val
            when "S"
              @rule.setSurfaceTailMany(false)
            when "P"
              @rule.setSurfaceTailMany(true)
            when "Inter"
              @rule.setSurfaceTailNumberFromIntermediateDOs(true)
            else
              raise "Error en surface tail number designation for adj phrase"
          end
        end
      end
      
      def rule
        @rule
      end
    end

    class CodeBlockLine < Line
      self.arg_opts = [[CodeBlock]]
      self.implied_directive = true
      
      def code
        args[0].val
      end
    end
  
    # Realm contents
  
    class Abbreviation < Line
      self.arg_opts = [[Identifier]]
      
      def abbrev
        args[0].val
      end

    end
    
    class ThisOntology < Line
      self.arg_opts = [[QuotedText]]
      
      def uri
        args[0].val
      end
    end
    
    class ExternalOntology < Line
      self.arg_opts = [[Identifier, QuotedText]]
      
      def abbrev
        args[0].val
      end
      
      def uri
        args[1].val
      end
    end
    
    class DependsRealm < Line
      self.arg_opts = [[Identifier]]
      
      def abbrev
        args[0].val
      end
    end
  
    # Repository Area contents
  
    class GeneralArchivalThings < Line
      self.arg_opts = [[]]
      # TODO: implement
    end
  
    class SharedArchivalThings < Line
      self.arg_opts = [[]]
      # TODO: implement
    end
  
    class SystemThings < Line
      self.arg_opts = [[]]
      # TODO: implement
    end
  
    class RepositoryArea < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ MultilingualText,
                                Comment,
                                GeneralArchivalThings,
                                SharedArchivalThings,
                                SystemThings ]

      include Java::MxOrgPescadorDefinitionsfiles::RepositoryAreaEl
      include NameAndComment

      def instantiate(realm)
        rep_area = realm.repositoryArea
        rep_area.setDefFileElement(self)
        add_name_and_comment(rep_area)
        rep_area.writeData
        rep_area.setOpts
        self.done
      end
    end
  
    class Realm < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ MultilingualText,
                                Comment,
                                Abbreviation,
                                ThisOntology,
                                ExternalOntology,
                                DependsRealm,
                                RepositoryArea ]
      self.make_index = true

      attr_reader(:realm)
      include Java::MxOrgPescadorDefinitionsfiles::RealmEl
      java_import 'mx.org.pescador.krmodel.KRModel'
      include NameAndComment
      
      def instantiate_first_pass
        
        e = contained(Abbreviation)
        @realm = KRModel.newRealm(e.abbrev, self)
        e.done
        
        add_name_and_comment(@realm)

        e = contained(ThisOntology)
        @realm.generateOntology(e.uri)
        e.done
        
        all_contained(ExternalOntology).each do |e| 
          @realm.linkExternalOnt(e.abbrev, e.uri) 
          e.done
        end
      end
      
      def instantiate_second_pass
        all_contained(DependsRealm).each do |e|
          @realm.addRealmDep(e.abbrev)
          e.done
        end
      end
      
      def instantiate_third_pass
        raise "Exactly one RepositoryArea section allowed per Realm" if count_contained(RepositoryArea) != 1
        contained(RepositoryArea).instantiate(@realm)
        @file.realm = @realm
        self.done
      end
      
    end
  
    # DefinitionSet contents
    # Vocabulary contents
    # Class, Property and DataType contents
  
    class SubClassOf < Line
      self.arg_opts = [[URI]]

      include FirstArgIsURI

    end
  
    class SubPropertyOf < Line
      self.arg_opts = [[URI]]
      
      include FirstArgIsURI
    end
  
    class SubDataTypeOf < Line
      self.arg_opts = [[URI]]
      
      include FirstArgIsURI      
    end
  
    class Range < Line
      self.arg_opts = [[URI]]
      
      include FirstArgIsURI
    end
  
    class Domain < Line
      self.arg_opts = [[URI]]
      
      include FirstArgIsURI
    end
  
    class ComparisonVector < Line
      self.arg_opts = [[Identifier, Identifier], [Identifier, Identifier, DefaultStr]]

      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.CompatibleType'
      
      def return_class
        CompatibleType.get(args[0].val)
      end
      
      def ident
        args[1].val
      end
      
      def is_default
        args[2] ? true : false
      end
      
      def j_def_file_el
#        self.j
        self
      end
    end
  
    class Hardcoded < Line
      self.arg_opts = [[]]
    end
  
    class BindToRuleSet < Line
      self.arg_opts = [[Identifier]]
      
      def ident
        args[0].val
      end
    end
  
    class UnOrderable < Line
      self.arg_opts = [[]]
    end
    
    class Groupable < Line
      self.arg_opts = [[]]
    end

    class UnGroupable < Line
      self.arg_opts = [[]]
    end
    
    class Gender < Line
      self.arg_opts = [[Identifier, Identifier]]
      # first argument is language
      # Second is M or F
      
      java_import 'mx.org.pescador.krmodel.search.SpanishGender'
      
      def val
        if (args[0].val != "es")
          throw "Only able to set gender for Spanish, currently"
        end
          
        case args[1].val
          when "M"
            SpanishGender::MASCULINE
          when "F"
            SpanishGender::FEMININE
          else
            throw "Incorrect gender designation"
        end
      end
      
    end
    
    class Class < Section
      self.section_id_opts = [URI]
      self.allowed_contents = [ MultilingualText,
                                Comment,
                                SubClassOf,
                                Hardcoded,
                                UnGroupable,
                                Gender ]
      self.make_index = true

      include Java::MxOrgPescadorDefinitionsfiles::OntTermEl
      java_import 'mx.org.pescador.krmodel.operations.DOModifier'
      
      include OntTerm

      def get_existing_term
        # import here so we don't initialize this class too soon
        java_import 'mx.org.pescador.krmodel.graphelements.Graph'
        Graph.getConcreteCls(@id.localURIPart, @realm.ont)
      end
      
      def generate_term
        DOModifier.generateConcreteCls(@id.localURIPart, @realm.ont)
      end

      def instantiate_second_pass
        all_contained(SubClassOf).each do |e|
          graph_part = @realm.getGraphPart(e.prefix)
          cls = Graph.getConcreteCls(e.localURIPart, graph_part)
          @ont_term.addSubClassOf(cls)
          e.done
        end
        if contained(UnGroupable)
          @ont_term.setUnGroupable
        end
        @ont_term.writeData
        
        gender_el = contained(Gender)
        if (gender_el)
          @ont_term.setSpanishGender(gender_el.val)
        end
        
        self.done
      end
      
    end

    # a sort of poor man's inference; really means: if this option is set on prop y, then
    # if A-x->B-y->C, then in creating groups of search results (and descriptions thereof)
    # A-x->C will be taken to be true and used instead of the longer path
    class CompactInSearch < Line
      self.arg_opts = [[]]
    end

    class DontTraverseInSearch < Line
      self.arg_opts = [[]]
    end
  
    class Property < Section
      self.section_id_opts = [URI]
      self.allowed_contents = [ MultilingualText,
                                Comment,
                                SubPropertyOf,
                                Range,
                                Domain,
                                Hardcoded,
                                AdjPhraseRule,
                                SearchWeight,
                                CompactInSearch,
                                DontTraverseInSearch ]
      self.make_index = true
      
      include Java::MxOrgPescadorDefinitionsfiles::OntTermEl
      java_import 'mx.org.pescador.krmodel.operations.DOModifier'
      java_import 'mx.org.pescador.krmodel.graphelements.Property'
      
      include OntTerm

      def get_existing_term
        # import here so we don't initialize this class too soon
        java_import 'mx.org.pescador.krmodel.graphelements.Graph'
        Graph.getProperty(@id.localURIPart, @realm.ont)
      end
      
      def generate_term
        DOModifier.generateProperty(@id.localURIPart, @realm.ont)
      end

      def instantiate_second_pass
        all_contained(AdjPhraseRule).each do |e| 
          e.instantiate
          @ont_term.addAdjPhaseRule(e.rule)
          e.done
        end

        searchWeightEl = contained(SearchWeight)
        if searchWeightEl
          @ont_term.setSearchWeight(searchWeightEl.val.to_i)
        end
      
        all_contained(SubPropertyOf).each do |e|
          graph_part = @realm.getGraphPart(e.prefix)
          prop = Graph.getProperty(e.localURIPart, graph_part)
          @ont_term.addSubPropertyOf(prop)
          e.done
        end

        all_contained(Range).each do |e|
          graph_part = @realm.getGraphPart(e.prefix)
          cls = Graph.getClass(e.localURIPart, graph_part)
          @ont_term.addRange(cls)
          e.done
        end
        
        all_contained(Domain).each do |e|
          graph_part = @realm.getGraphPart(e.prefix)
          cls = Graph.getClass(e.localURIPart, graph_part)
          @ont_term.addDomain(cls)
          e.done
        end
        
        @ont_term.writeData
        
        if (contained(CompactInSearch))
          @ont_term.setCompactInSearch
        end
        
        if (contained(DontTraverseInSearch))
          @ont_term.setDontTraverseInSearch
        end
        
        self.done
      end

      
    end
  
    class AbstractDataType < Section
      self.section_id_opts = [URI]
      self.allowed_contents = [ MultilingualText,
                                Comment,
                                SubDataTypeOf,
                                ComparisonVector,
                                Hardcoded,
                                UnOrderable,
                                Groupable ]
      self.make_index = true
      
      include Java::MxOrgPescadorDefinitionsfiles::OntTermEl
      java_import 'mx.org.pescador.krmodel.operations.DOModifier'
      include DataType

      def get_existing_term
        # import here so we don't initialize this class too soon
        java_import 'mx.org.pescador.krmodel.graphelements.Graph'
        Graph.getAbstractDataType(@id.localURIPart, @realm.ont)
      end
      
      def generate_term
        DOModifier.generateAbstractDataType(@id.localURIPart, @realm.ont)
      end
      
    end
  
    class ComplexDataType < Section
      self.section_id_opts = [URI]
      self.allowed_contents = [ MultilingualText,
                                Comment,
                                SubDataTypeOf,
                                ComparisonVector,
                                Hardcoded,
                                BindToRuleSet,
                                UnOrderable,
                                Groupable ]
      self.make_index = true

      include Java::MxOrgPescadorDefinitionsfiles::OntTermEl
      java_import 'mx.org.pescador.krmodel.operations.DOModifier'
      include DataType

      def get_existing_term
        # import here so we don't initialize this class too soon
        java_import 'mx.org.pescador.krmodel.graphelements.Graph'
        Graph.getComplexDataType(@id.localURIPart, @realm.ont)
      end
      
      def generate_term
        DOModifier.generateComplexDataType(@id.localURIPart, @realm.ont)
      end

      def instantiate_third_pass
        set_rule_set_for_values
      end
      
    end
  
    class FundamentalDataType < Section
      self.section_id_opts = [URI]
      self.allowed_contents = [ MultilingualText,
                                Comment,
                                SubDataTypeOf,
                                ComparisonVector,
                                Hardcoded,
                                BindToRuleSet,
                                UnOrderable,
                                Groupable ]
      self.make_index = true

      include Java::MxOrgPescadorDefinitionsfiles::OntTermEl
      java_import 'mx.org.pescador.krmodel.operations.DOModifier'
      include DataType

      def get_existing_term
        # import here so we don't initialize this class too soon
        java_import 'mx.org.pescador.krmodel.graphelements.Graph'
        Graph.getFundDataType(@id.localURIPart, @realm.ont)
      end
      
      def generate_term
        DOModifier.generateFundDataType(@id.localURIPart, @realm.ont)
      end
  
      def instantiate_third_pass
        set_rule_set_for_values
      end

    end
  
    class Vocabulary < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ Class,
                                Property,
                                AbstractDataType,
                                ComplexDataType,
                                FundamentalDataType]
    end
  
    # RuleSet contents
    # Structure contents
    # Descriptor contents
  
    class PropertyLine < Line
      self.name="property"
      self.arg_opts = [[URI]]
      
      include FirstArgIsURI
    end
  
    class MinCardinality < Line
      self.arg_opts = [[Integer]]
    end
  
    class MaxCardinality < Line
      self.arg_opts = [[Integer]]
    end
  
    class MaxNonInfCardinality < Line
      self.arg_opts = [[Integer]]
    end
  
    class Multilingual < Line
      self.arg_opts = [[]]
    end
  
    class MultipleOrdered < Line
      self.arg_opts = [[]]
    end
  
    class OutClass < Line
      self.arg_opts = [[URI]]
    end
  
    class OutDataType < Line
      self.arg_opts = [[URI]]
    end
  
    class OutFromGroup < Line
      self.arg_opts = [[Identifier]]
    end
  
    class OutRequirement < Line
      self.arg_opts = [[FromPropRangeStr]]
    end
  
    class OutValue < Line
      self.arg_opts = [[URI],[Identifier]]
    end
  
    class UseDefinition < Line
      self.arg_opts = [[Identifier]]
      
      def descriptor_id
        args[0].val
      end
    end
 
    class ForImageSrcString < Line
      self.arg_opts = [[]]
    end
  
    class Descriptor < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ PropertyLine,
                                MinCardinality,
                                MaxCardinality,
                                MaxNonInfCardinality,
                                Multilingual,
                                MultipleOrdered,
                                OutClass,
                                OutDataType,
                                OutFromGroup,
                                OutRequirement,
                                OutValue,
                                UseDefinition,
                                ForImageSrcString ]
      self.make_index = true
      
      include InWrapperInRuleSet

      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      java_import 'mx.org.pescador.krmodel.graphelements.DescriptorMappingType'

                # TODO: Fix JRB so that it may return a fully-functional Ruby object from a Java class,
      # so we can avoid this ugly hack.
      @@postponed_el_index = Hash.new
      
      def instantiate_first_pass
        # import here so we don't initialize this class too soon
        java_import 'mx.org.pescador.krmodel.graphelements.Graph'
        
        ordered = contained(MultipleOrdered)
        mult_ling = contained(Multilingual)
        prop_el = contained(PropertyLine)
        for_img_src = contained(ForImageSrcString)        
        @use_def_el = contained(UseDefinition)
        
        @krrr = RuleManager.generateSingleDescRelRule(@id.val, rule_set, self)
        
        if (@use_def_el)
          if (prop_el || ordered || mult_ling)
            raise "If a Descriptor section contains a useDefinition directive it may not contain property, multipleOrdered or multilingual directives." + @krrr.fullIdent
          end
          @@postponed_el_index[@krrr.fullIdent] = self
        else
          if (ordered && mult_ling)
            raise "Descriptors that are both ordered and multilingual not yet implemented: " + @krrr.fullIdent
          end
  
          if (ordered)
            d_map_type = DescriptorMappingType::ORDERED
            ordered.done
          elsif (mult_ling)
            d_map_type = DescriptorMappingType::STRUCTURED_MULTILIGNUAL
            mult_ling.done
          else
            d_map_type = DescriptorMappingType::SIMPLE_PROP
          end
          
          if (count_contained(PropertyLine) == 1)
            prop_gp = @file.realm.getGraphPart(prop_el.prefix)
            prop = Graph.getProperty(prop_el.localURIPart, prop_gp)
            prop_el.done
          else
            raise "Descriptor must declare exactly one property: " + @krrr.fullIdent
          end
          
          if (for_img_src)
            @krrr.setForImageSrcString()
          end
          
          @krrr.setMappingType(d_map_type)
          @krrr.setProp(prop)
          
          # TODO: implement struct rules
          
          @krrr.setInitialized
          self.done
        end    
      end
     
      def instantiate_second_pass(circular_recursion_check=nil)
      
        return if (@krrr.initialized)
     
        uses_krrr = RuleManager.getBaseStructureKRRelRule(@use_def_el.descriptor_id, rule_set)
     
        if (rule_set.baseStructureIncludes(uses_krrr))
          raise "useDefinition may not refer to a Descriptor in the same Rule Set: " + @krrr.fullIdent
        end
  
        if (!uses_krrr.initialized)
          if (circular_recursion_check)
            if (circular_recursion_check.include?(@krrr.fullIdent))
              raise "Circular dependency found with useDefinition directive: #{@krrr.ident}"
            end
            circular_recursion_check.push(@krrr.fullIdent)
          else
            circular_recursion_check = [@krrr.fullIdent]
          end
  
          # this lookup is hackish but unavoidable because of current JRB limitations
          uses_krrr_el = @@postponed_el_index[uses_krrr.fullIdent]
          uses_krrr_el.instantiate_second_pass(circular_recursion_check)
        end
  
        @krrr.setMappingType(uses_krrr.mappingType)
        @krrr.setProp(uses_krrr.prop)
        
        # TODO: implement copying of struct rules
        @krrr.setInitialized
        self.done
      end
     
    end
  
    class Structure < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [Descriptor]
      
    end
  
    # Inference Rules content
    # Inference Rule content
  
    class InferenceRule < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [CodeBlockLine]
      self.make_index = true
      
      include InWrapperInRuleSet
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'

      def instantiate
        if (count_contained(CodeBlockLine) != 1)
          raise "Inference Rule must contain exactly one code block."
        end
        code = contained(CodeBlockLine).code
        RuleManager.generateInfRule(@id.val, code, rule_set, self)
      end
    end
  
    class InferenceRules < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [InferenceRule]
    end
  
    # KRRelationRules content
    # KRRelationRule content
  
    class KRRelationRef < Line
      self.arg_opts = [[Identifier], [KRRelRefPartWithOptions], [LinkingKRRelRef]]
      self.implied_directive = true
      
      def krrr_part_els
        if ((args[0].class == Identifier) || (args[0].class == KRRelRefPartWithOptions))
          [args[0]]
        else
          args[0].val
        end
      end
      
    end
  
    class Conditions < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ CodeBlockLine ]
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      def add_conditions(krrr)
        all_contained(CodeBlockLine).each do |code_block_line_el|
          RuleManager.generateKRRRCondition(krrr, code_block_line_el.code, self)
          code_block_line_el.done
        end
      end
    end
  
    class StructRules < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ MinCardinality,
                                MaxCardinality,
                                MaxNonInfCardinality,
                                OutClass,
                                OutDataType,
                                OutFromGroup,
                                OutRequirement,
                                OutValue ]
    end

    class TraverseInSearch < Line
      self.arg_opts = [[]]
    end

    class MenotymizeInSearch < Line
      self.arg_opts = [[]]
    end
  
    class KRRelationRule < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ KRRelationRef,
                                Conditions,
                                StructRules,
                                TraverseInSearch,
                                MenotymizeInSearch,
                                MultilingualText,
                                SearchWeight,
                                #CompactInSearch,
                                AdjPhraseRule  ]
      self.make_index = true
      
      include InWrapperInRuleSet
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      def instantiate_first_pass
        @krrr = RuleManager.generateMultipleDesRelRule(@id.val, rule_set, self)
      end
      
      def instantiate_second_pass
        if (count_contained(KRRelationRef) != 1)
          raise "KRRelationRule must contain exactly one path definition."
        end
        contained(KRRelationRef).krrr_part_els.each do |krrr_part_el|
          if (krrr_part_el.class == Identifier)
            id = krrr_part_el.val
            inv = false
            non_inf = false
          else
            id = krrr_part_el.id.val
            inv = krrr_part_el.inv
            non_inf = krrr_part_el.non_inf
          end
          krrr_part = RuleManager.getKRRelationRule(id, rule_set)
          @krrr.addDeclaredPart(krrr_part, inv, non_inf)
        end
        
        if contained(TraverseInSearch)
          @krrr.setTraverseInSearch
        end

        if contained(MenotymizeInSearch)
          @krrr.setMenotymizeInSearch
        end
        
        # Un código igual a esto aparece en Property       
        all_contained(AdjPhraseRule).each do |e| 
          e.instantiate
          @krrr.addAdjPhaseRule(e.rule)
          e.done
        end

        all_contained(MultilingualText).each do |e| 
          e.add_to_multi_string(@krrr.label)
          e.done
        end
        
        searchWeightEl = contained(SearchWeight)
        if searchWeightEl
          @krrr.setSearchWeight(searchWeightEl.val.to_i)
        end
        
        @krrr.closeParts
        
        if (count_contained(Conditions) > 1)
          raise "KRRelationRule may contain no more than one Conditions section."
        end
        conditions_el = contained(Conditions)
        if conditions_el
          conditions_el.add_conditions(@krrr)
          conditions_el.done
        end
        
        # TODO: implement struct rules
        self.done
      end
      
    end
  
    class KRRelationRules < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [KRRelationRule]
    end
  
    # CompVectorFunctions content
  
    class CompVectorFunction < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [CodeBlockLine]
      self.make_index = true
            
      include InWrapperInRuleSet
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      def instantiate
        if (count_contained(CodeBlockLine) != 1)
          raise "Comparison vector function must contain exactly one code block."
        end
        code_block_el = contained(CodeBlockLine)
        code = code_block_el.code      
        RuleManager.generateCompVectorFunction(@id.val, code, rule_set, self)
        code_block_el.done
        self.done
      end
    end
  
    class CompVectorFunctions < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [CompVectorFunction]
    end
  
    # BPVFunctions content
  
    class DefaultTextBPVFunction < Line
      self.arg_opts = [[]]
    end 
    
    class ResultsSearchable < Line
      self.arg_opts = [[]]
    end 
  
    class OrderUsing < Line
      self.arg_opts = [[Identifier]]
      include FirstArgIsIdentifierAndActsAsVal
    end
  
    class Slot < Line
      self.arg_opts = [[Identifier], 
                       [KRRelRefPartWithOptions],
                       [Identifier, CaptureSearchHits], 
                       [KRRelRefPartWithOptions, CaptureSearchHits]]
              
      def krrr_id
        args[0].val
      end         

      def krrr_inv
        if (args[0].class == Identifier)
          false
        else
          args[0].inv
        end
      end
      
      # Note: we're ignoring here the non-inf option, because we're not using it anywhere
      def capture_search_hits
        args[1].class == CaptureSearchHits
      end
    end
    
    class TextBPVFunction < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ DefaultTextBPVFunction,
                                Multilingual,
                                OrderUsing,
                                CodeBlockLine,
                                ResultsSearchable,
                                Slot ]
      self.make_index = true
      include InWrapperInRuleSet
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      def instantiate_first_pass
        if (count_contained(CodeBlockLine) != 1)
          raise "Text BPV function must contain exactly one code block."
        end
        code_block_el = contained(CodeBlockLine)
        code = code_block_el.code
        code_block_el.done
        
        is_default_el = contained(DefaultTextBPVFunction)
        if (is_default_el)
          is_default = true
          is_default_el.done
        else
          is_default = false
        end
        
        order_using_el = contained(OrderUsing)
        if (order_using_el)
          order_using = rule_set.krRelationRule(order_using_el.val)
          order_using_el.done
        else
          order_using = nil
        end

        multilingual_el = contained(Multilingual)
        if (multilingual_el)
          multilingual = true
          multilingual_el.done
        else
          multilingual = false
        end

#(String ident, String code, boolean multilingual, RuleSet rs, 
#			boolean isDefault, KRRelationRule orderUsing, RuleEl ruleEl)
        
        @func = RuleManager.generateRubyTextBPVFunction(@id.val, 
                                                       code,
                                                       multilingual,
                                                       rule_set, 
                                                       is_default,
                                                       order_using,
                                                       self)

        results_searchable_el = contained(ResultsSearchable)
        if (results_searchable_el)
          @func.setResultsSearchable(true)
          results_searchable_el.done
        else
          @func.setResultsSearchable(false)
        end
        
        all_contained(Slot).each do |slot_el|
          
          krrr = RuleManager.getKRRelationRule(slot_el.krrr_id, rule_set)
          inv = slot_el.krrr_inv
          capture_search_hits = slot_el.capture_search_hits
          
          @func.addSlot(krrr, inv, capture_search_hits)
        end
      end
      
      def instantiate_second_pass
        @func.setUpDependencies
        self.done
      end
            
    end
  
    class DefaultImageBPVFunction < Line
      self.arg_opts = [[]]
    end
  
    class ImageBPVFunction < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ DefaultImageBPVFunction,
                                CodeBlockLine ]
      self.make_index = true
      include InWrapperInRuleSet
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      def instantiate
        if (count_contained(CodeBlockLine) != 1)
          raise "Image BPV function must contain exactly one code block."
        end
        code_block_el = contained(CodeBlockLine)
        code = code_block_el.code
        code_block_el.done
        
        is_default_el = contained(DefaultImageBPVFunction)
        if (is_default_el)
          is_default = true
          is_default_el.done
        else
          is_default = false
        end
        
        RuleManager.generateRubyImageBPVFunction(@id.val, 
                                                 code,
                                                 rule_set,
                                                 is_default,
                                                 self)
        self.done
      end
    end
  
    class BPVFunctions < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ TextBPVFunction,
                                ImageBPVFunction ]
    end
  
    # Descriptions content
    # NonDefaultDescFragments content
    # CreateTemplate and ModifyTemplate content

  
    class DefaultOrderBy < Line
      self.arg_opts = [[Identifier]]
      
      def ident
        args[0].val
      end
    end
  
    class CopyOfTemplate < Line
      self.arg_opts = [[Identifier]]
      attr_reader(:copy_of_template)
      
      def ident
        args[0].val
      end
      
      def instantiate(rule_set)
        @copy_of_template = rule_set.krRelationRule(ident)
      end
    end
  
    class ImageBPV < Line
      self.arg_opts = [[Identifier]]
      
      def instantiate
      end
      
    end
  
    class TextBPV < Line
      self.arg_opts = [[Identifier], [Identifier, Identifier]]
      attr_reader(:text_bpv_template)
        
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      def ident
        args[0].val
      end
      
      def has_func
        args[1] ? true : false
      end
      
      def func(rule_set)
        RuleManager.getTextBPVFunction(args[1].val, rule_set)
      end
      
      def instantiate(rule_set)
        @text_bpv_template = RuleManager.generateTextBPVTemplate(self)
        krrr = rule_set.krRelationRuleWithOutExp(ident)
        
        if (krrr != nil)
          @text_bpv_template.setKrrr(krrr)
          @text_bpv_template.setFuncOnKRR(func(rule_set)) if (has_func)
        else
          func = rule_set.textBPVFunction(ident)
          if (func == nil)
            raise "No text bpv funciton here... " + ident + " in " + rule_set.ident
          end
          @text_bpv_template.setTextBPVFunction(func)
        end
      end
    end
  
    class UniqueImageBPV < Line
      self.arg_opts = [[CodeBlock]]
      
      def instantiate(rule_set)
      end
      
    end
  
    class UniqueTextBPV < Line
      self.arg_opts = [[CodeBlock]]
      attr_reader(:unique_text_bpv)
      
     java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      include UniqueId
      
      def code
        args[0].val
      end
      
      def instantiate(rule_set)
        new_ident = u_ident(rule_set)
        u_text_bpv = RuleMananger.generateRubyUniqueBPVFunction(new_ident, code, self)
        @unique_text_bpv = RuleMananger.generateTextBPVTemplate(self, u_text_bpv)
      end
    end
  
    class Label < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ MultilingualText,
                                TextBPV,
                                ImageBPV,
                                UniqueTextBPV,
                                UniqueImageBPV ]
      
      attr_reader(:label_template)
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      include MultiStringCreation
      
      def instantiate(rule_set)
          @label_template = RuleManager.generateLabelTemplate(self)
        
        if (contained(MultilingualText))
            multilingual = @label_template.getMultiString()
            add_all_to_multi_string(multilingual, all_contained(MultilingualText))
        elsif (contained(TextBPV))
            text_bpv_el = contained(TextBPV)
            text_bpv_el.instantiate(rule_set)
            @label_template.setTextBPV(text_bpv_el.text_bpv_template)
        elsif (contained(ImageBPV))
            image_bpv_el = contained(ImageBPV)
            raise "Image BPV not implemented in section Label"
        elsif (contained(UniqueTextBPV))
            unique_text_bpv_el = contained(UniqueTextBPV)
            unique_text_bpv_el.instantiate(rule_set)
            @label_template.setUniqueTextBPV(unique_text_bpv_el.unique_text_bpv)
        elsif (containde(UniqueImageBPV))
            unique_image_bpv_el = containde(UniqueImageBPV)
            raise "Unique image BPV not implemented in section Label"
        else
        end
      end
      
    end
    
    class Value < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ MultilingualText,
                                TextBPV,
                                ImageBPV,
                                UniqueTextBPV,
                                UniqueImageBPV ]

      include Java::MxOrgPescadorDefinitionsfiles::RuleEl 
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      attr_reader(:value_template)
      
      include MultiStringCreation    
                      
      def instantiate(rule_set)
        @value_template = RuleManager.generateValueTemplate(self)
        
        if (contained(MultilingualText))
            multilingual = @value_template.getMultiString()
            add_all_to_multi_string(multilingual, all_contained(MultilingualText))
        elsif (contained(TextBPV))
            text_bpv_el = contained(TextBPV)
            text_bpv_el.instantiate(rule_set)
            @value_template.setTextBPV(text_bpv_el.text_bpv_template)
        elsif (contained(ImageBPV))
            image_bpv_el = contained(ImageBPV)
            raise "Image BPV not implemented in section Value"
        elsif (contained(UniqueTextBPV))
            unique_text_bpv_el = contained(UniqueTextBPV)
            unique_text_bpv_el.instantiate(rule_set)
            @value_template.setUniqueTextBPV(unique_text_bpv_el.unique_text_bpv)
        elsif (containde(UniqueImageBPV))
            unique_image_bpv_el = containde(UniqueImageBPV)
            raise "Unique image BPV not implemented in section Value"
        else
        end
      
      end
    end
    
    class CreateTemplate < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ CopyOfTemplate,
                                MultilingualText,
                                Label,
                                ImageBPV,
                                TextBPV,
                                UniqueImageBPV,
                                UniqueTextBPV ]
      self.make_index = true
    end
  
    class ModifyTemplate < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ MultilingualText,
                                Label,
                                ImageBPV,
                                TextBPV,
                                UniqueImageBPV,
                                UniqueTextBPV ]
    end
    
    class NonDefaultDescFragments < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ CreateTemplate,
                                ModifyTemplate ]
    end
  
    # VariableDesc content
  
    class Df < Line
      self.arg_opts = [[Identifier]]
      
      attr_reader(:df)
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager' 
      
      def ident
        args[0].val
      end
      
      def instantiate(rule_set)
        krrr = rule_set.krRelationRuleWithOutExp(ident)
        
        if(krrr != nil)
          @df = RuleManager.generateDfTemplate(self, krrr)
        else
          # TODO: ??
          raise "Descfragment no implementado para Create Template: " + ident
        end
      end
    end
  
    # UniqueDF content
  
    class LinkTo < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ MultilingualText ]
      
      attr_reader(:link_to_template)
      java_import 'mx.org.pescador.krmodel.rules.RuleManager' 
      include MultiStringCreation
            
      def instantiate
        @link_to_template = RuleManager.generateLinkToTemplate(self, @id.val)
        multilingual = @link_to_template.getMultiString()
        add_all_to_multi_string(multilingual, all_contained(MultilingualText))
      end
    end
  
    class Anchor < Line
      self.arg_opts = [[Identifier], [ValueStr]]
      self.make_index = true
      
      def ident
        args[0].val
      end
    end

    class UnShowable < Line
      self.arg_opts = [[]]
    end

    class OnlySearchShowable < Line
      self.arg_opts = [[]]
    end

    class ShowInstead < Line
      self.arg_opts = [[Identifier]]
      
      def ident
        args[0].val
      end
    end
  
    class UniqueDF < Section
      self.section_id_opts = [nil, Identifier]
      self.allowed_contents = [ CopyOfTemplate,
                                Label,
                                Value,
                                LinkTo,
                                Anchor,
                                UnShowable,
                                OnlySearchShowable,
                                ShowInstead ]
      
      attr_reader(:unique_df)

      include Java::MxOrgPescadorDefinitionsfiles::RuleEl      
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      def have_format
          if((contained(Label) && contained(Value) || contained(CopyOfTemplate)) || 
             (contained(Label) && contained(CopyOfTemplate)) ||
             (contained(Value) && contained(CopyOfTemplate)) ||
             (!contained(Label) && !contained(Value)))
             return true
          else
             return false
          end
      end
      
      def instantiate(rule_set)
        if(@id != nil)
          @unique_df = RuleManager.generateUniqueDfTemplateConfig(self, @id.val)
        else
          @unique_df = RuleManager.generateUniqueDfTemplateConfig(self, nil)
        end
        
        if(have_format)
          contents.each do |el|
            cls = el.class
            
            if (cls == LinkTo)
              el.instantiate
              @unique_df.setLinkTo(el.link_to_template)
            elsif (cls == UnShowable)
              @unique_df.setUnShowable
            elsif (cls == OnlySearchShowable)
              @unique_df.setOnlySearchShowable
            elsif (cls == ShowInstead)
              # we're assuming that the argument of ShowInstead refers to a UniquedF
              # that has been previously mentioned in the same variabledesc
              @unique_df.setShowInsteadIdent(el.ident)
            else
              el.instantiate(rule_set)
          
              if (cls == Label)
                  @unique_df.setLabelTemplate(el.label_template)
              elsif (cls == Value)
                  @unique_df.setValueTemplate(el.value_template)
              elsif (cls == Anchor)
                  @unique_df.setAnchor(el.ident)
              elsif (cls == CopyOfTemplate)
                  @unique_df.setCopyOfTemplate(el.copy_of_template)
              end
            end
          end
         else
            raise "Incorret format in UniqueDF"
         end
      end
    end
  
    class VariableDesc < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ Df,
                                UniqueDF ]
                                
      self.make_index = true
                   
      attr_reader(:variable_desc)

      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      include InWrapperInRuleSet 
                   
      def instantiate
        @variable_desc = RuleManager.generateVariableDescOpts(self)
        rule_set.setVariableDescTemplateOpts(@variable_desc)
        
        contents.each do |el|
          cls = el.class
          el.instantiate(rule_set)
          
          if(cls == Df)
            @variable_desc.addDescFragment(el.df)
          else
            @variable_desc.addUniqueDF(el.unique_df)
          end
        end
      end
    end
  
    # VariableDesc directive
  
    class VariableDescLine < Line
      self.directive_same_token_as = VariableDesc
      self.arg_opts = [[DefaultStr]]
    end
  
    # ShortDesc and FullDesc contents
    # Area contents
  
    class CodeInDescTemplateLine < Line
      self.arg_opts = [[CodeInDescTemplate]]
      self.implied_directive = true
      
      def code
        args[0].val
      end
    end
    
    class Title < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ MultilingualText,
                                TextBPV,
                                UniqueTextBPV ]

      include Java::MxOrgPescadorDefinitionsfiles::RuleEl      
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'  
      attr_reader(:title_template)
      
      include MultiStringCreation    
                      
      def instantiate(rule_set)
        if (count_contained(TextBPV) > 1)
          raise "Title must contain exactly one TextBPV."
        elsif (count_contained(UniqueTextBPV) > 1)
          raise "Title must contain exactly one UniqueTextBPV"
        end
        
        @title_template = RuleManager.generateDescTileTemplate(self)
        
        if (contained(MultilingualText))
            multilingual = @title_template.getMultiString()
            add_all_to_multi_string(multilingual, all_contained(MultilingualText))
        elsif (contained(TextBPV))
            text_bpv_el = contained(TextBPV)
            text_bpv_el.instantiate(rule_set)
            @title_template.setTextBPV(text_bpv_el.text_bpv_template)
        else
            unique_text_bpv_el = contained(UniqueTextBPV)
            unique_text_bpv_el.instantiate(rule_set)
            @title_template.setUniqueTextBPV(unique_text_bpv_el.unique_text_bpv)
        end
        
      end
    end
  
    class BlockSection < Section
      self.section_id_opts = [nil, Identifier]
      self.allowed_contents = [ Label,
                                Df,
                                TextBPV,
                                ImageBPV,
                                UniqueDF ]
      self.make_index = true
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      attr_reader(:block_section_template)
      
      def instantiate(rule_set)
        if(@id != nil)
          @block_section_template = RuleManager.generateDescBlockSectionTemplate(self, @id.val)
        else
          @block_section_template = RuleManager.generateDescBlockSectionTemplate(self, nil)
        end
        
        if(!contained(Label))
          raise "Block Section must have a Label section"
        end
        
        contents.each do |el|
          cls = el.class
          el.instantiate(rule_set)
          
          if (cls == Df)
            @block_section_template.addDescFragment(el.df)
          elsif (cls == UniqueDF)
            @block_section_template.addUniqueDF(el.unique_df)
          elsif (cls == Label)
            @block_section_template.setLabelTemplate(el.label_template)
          elsif (cls == TextBPV)
            @block_section_template.addTextBPVTemplate(el.text_bpv_template)
          else
            raise "ImageBPV for block section not implemented"
          end
        end
      end
      
    end
  
    class Block < Section
      self.section_id_opts = [nil, Identifier]
      self.allowed_contents = [ Title,
                                BlockSection,
                                Df,
                                UniqueDF,
                                CodeInDescTemplateLine ]
                                
      self.make_index = true

      include Java::MxOrgPescadorDefinitionsfiles::RuleEl      
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      attr_reader(:block_template)
      
      def instantiate(rule_set)
        if(@id != nil)
          @block_template = RuleManager.generateDescBlockTemplate(self, @id.val)
        else
          @block_template = RuleManager.generateDescBlockTemplate(self, nil)
        end
        
        contents.each do |el|
          cls = el.class
          el.instantiate(rule_set)
          
          if (cls == Df)
            @block_template.addDescFragment(el.df)
          elsif (cls == UniqueDF)
            @block_template.addUniqueDF(el.unique_df)
          elsif (cls == BlockSection)
            @block_template.addBlockSection(el.block_section_template)
          elsif (cls == CodeInDescTemplateLine)
            raise "CodeInDescTemplateLine not implemented in block"
          else
            if (count_contained(Title) > 1)
              raise "Block must contain exactly one title."
            else
              @block_template.setDescTitleTemplate(el.title_template)
            end
          end
        end
      end
    end
  
    class Area < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ Title,
                                Block,
                                Df,
                                UniqueDF,
                                TextBPV,
                                ImageBPV,
                                UniqueTextBPV,
                                UniqueImageBPV,
                                CodeInDescTemplateLine ]
      
      self.make_index = true
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager' 
      
      attr_reader(:area_template)
            
      include MultiStringCreation
      
      def instantiate(rule_set)
        @area_template = RuleManager.generateDescAreaTemplate(self, @id.val)
        
        contents.each do |el|
          cls = el.class
          
            el.instantiate(rule_set)
            if (cls == Block)
              @area_template.addDescBlockTemplate(el.block_template)
            elsif (cls == Df)
              @area_template.addDescFragment(el.df)
            elsif (cls == UniqueDF)
              @area_template.addUniqueDF(el.unique_df)
            elsif (cls == TextBPV)
              @area_template.addTextBPVTemplate(el.text_bpv_template)
            elsif (cls == ImageBPV)
              raise "Image BPV no implementado"
            elsif (cls == UniqueTextBPV)
              @area_template.addUniqueTextBPV(el.unique_text_bpv)
            elsif (cls == UniqueImageBPV)
              raise "Unique Image BPV no implementado"
            elsif (cls == CodeInDescTemplateLine)
              raise "CodeInDescTemplate no implementado"
            else
              if (count_contained(Title) > 1)
                raise "Area must contain exactly one title."
              else
                @area_template.setDescTitleTemplate(el.title_template)
              end
            end
        end
      end
    end
  
    class ShortDesc < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ Block,
                                Df,
                                UniqueDF,
                                TextBPV,
                                ImageBPV,
                                UniqueTextBPV,
                                UniqueImageBPV,
                                CodeInDescTemplateLine ]
     
      self.make_index = true
      
      include InWrapperInRuleSet    
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager' 
      
      def instantiate
        @short_desc = RuleManager.generateShortDesc(self)
        @short_desc.setDefinedByRS(rule_set)
        
        area_desc = @short_desc.getBlankArea()
         
        contents.each do |el|
          cls = el.class
          
            el.instantiate(rule_set)
            if (cls == Block)
              area_desc.addDescBlockTemplate(el.block_template)
            elsif (cls == Df)
              area_desc.addDescFragment(el.df)
            elsif (cls == UniqueDF)
              area_desc.addUniqueDF(el.unique_df)
            elsif (cls == TextBPV)
              area_desc.addTextBPVTemplate(el.text_bpv_template)
            elsif (cls == ImageBPV)
              raise "Image BPV no implementado"
            elsif (cls == UniqueTextBPV)
              area_desc.addUniqueTextBPV(el.unique_text_bpv)
            elsif (cls == UniqueImageBPV)
              raise "Unique Image BPV no implementado"
            elsif (cls == CodeInDescTemplateLine)
              raise "CodeInDescTemplate no implementado"
            end
        end
        rule_set.setShortDescTemplate(@short_desc)
      end                                                   
    end

    class TitleDesc < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ Df,
                                UniqueDF,
                                TextBPV ]
     
      self.make_index = true

      include InWrapperInRuleSet    

      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager' 
      
      def instantiate
        @title_desc = RuleManager.generateTitleDesc(self)
        @title_desc.setDefinedByRS(rule_set)
        
        area_desc = @title_desc.getBlankArea()
         
        contents.each do |el|
          cls = el.class
          
            el.instantiate(rule_set)
            if (cls == Df)
              area_desc.addDescFragment(el.df)
            elsif (cls == UniqueDF)
              area_desc.addUniqueDF(el.unique_df)
            elsif (cls == TextBPV)
              area_desc.addTextBPVTemplate(el.text_bpv_template)
            end
        end
        rule_set.setTitleDescTemplate(@title_desc)
      end   
    end
  
    class FullDesc < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ Area,
                                Block,
                                Df,
                                UniqueDF,
                                TextBPV,
                                ImageBPV,
                                UniqueTextBPV,
                                UniqueImageBPV,
                                CodeInDescTemplateLine ]
      
      self.make_index = true
                     
      include InWrapperInRuleSet    
      include MultiStringCreation
      include UniqueId
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      
      def instantiate
        @full_desc = RuleManager.generateFullDesc(self)
        @full_desc.setDefinedByRS(rule_set)
        
        if(!contained(Area))
          ident = u_ident(rule_set)
          area_desc = @full_desc.createBlankArea(self, ident)
        end
              
        contents.each do |el|
          cls = el.class
          
          if(cls == Area)
            el.instantiate(rule_set)
            @full_desc.setDescAreaTemplate(el.area_template.getIdent, el.area_template)
          else 
              el.instantiate(rule_set)
              if (cls == Block)
                area_desc.addDescBlockTemplate(el.block_template)
              elsif (cls == Df)
                area_desc.addDescFragment(el.df)
              elsif (cls == UniqueDF)
                area_desc.addUniqueDF(el.unique_df)
              elsif (cls == TextBPV)
                area_desc.addTextBPVTemplate(el.text_bpv_template)
              elsif (cls == ImageBPV)
                raise "Image BPV no implementado"
              elsif (cls == UniqueTextBPV)
                area_desc.addUniqueTextBPV(el.unique_text_bpv)
              elsif (cls == UniqueImageBPV)
                raise "Unique Image BPV no implementado"
              elsif (cls == CodeInDescTemplateLine)
                raise "CodeInDescTemplate no implementado"
              end
          end
        end
        rule_set.setFullDescTemplate(@full_desc)
      end                            
    end
  
    # ShortDesc and FullDesc directives
  
    class ShortDescLine < Line
      self.directive_same_token_as = ShortDesc
      self.arg_opts = [[DefaultStr]]
    end
  
    class FullDescLine < Line
      self.directive_same_token_as = FullDesc
      self.arg_opts = [[DefaultStr]]
    end
  
    class Descriptions < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [ DefaultOrderBy,
                                NonDefaultDescFragments,
                                VariableDesc,
                                VariableDescLine,
                                ShortDesc,
                                ShortDescLine,
				TitleDesc,
                                FullDesc,
                                FullDescLine ]
     
      self.make_index = true
      
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'

      def instantiate_opts       
        if(contained(DefaultOrderBy))
           default_order_by_el = contained(DefaultOrderBy)
           v_desc_tpl_opts_element_el = RuleManager.getVDescTplOptsElem(default_order_by_el.ident, is_in.rule_set)
           is_in.rule_set.addDefaultOrderBy(v_desc_tpl_opts_element_el)
        end
      end
    end
  
    class TypeInCode < Line
      self.arg_opts = [[Identifier]]
      
    java_import 'mx.org.pescador.krmodel.CompatibleType'
      
      def type
        CompatibleType.get(args[0].val)
      end
    end
  
    class ForPersistentGroup < Line
      self.arg_opts = [[]]
    end

    # deprecated ###
    class ForMembersOfMainLevelSOCs < Line
      self.arg_opts = [[]]
    end

    class ForAllMainLevelSOCMembersMembers < Line
      self.arg_opts = [[]]
    end
  
    class RuleSet < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ Structure,
                                InferenceRules,
                                KRRelationRules,
                                CompVectorFunctions,
                                BPVFunctions,
                                Descriptions,
                                TypeInCode,
                                ForPersistentGroup,
                                ForMembersOfMainLevelSOCs,
                                ForAllMainLevelSOCMembersMembers ]
      self.make_index = true
      
      include Java::MxOrgPescadorDefinitionsfiles::RuleSetEl
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
      java_import 'mx.org.pescador.krmodel.KRModel'
      
      attr_reader(:rule_set)
      
      def instantiate_first_pass
        for_persistent_grp = (contained(ForPersistentGroup) ? true : false)
      
        @rule_set = RuleManager.generateRuleSet(@id.val, @file.realm, 
          for_persistent_grp, self)

        # deprecated ###
        if (contained(ForMembersOfMainLevelSOCs))
          KRModel.setMainLevelSOCsMembersRS(@rule_set)
        end

        # deprecated ###
        if (contained(ForAllMainLevelSOCMembersMembers))
          KRModel.setAllMainLevelSOCMembersMembersRS(@rule_set)
        end
    
        type_in_code_el = contained(TypeInCode)
        if type_in_code_el
          @rule_set.setTypeInCode(type_in_code_el.type)
          type_in_code_el.done
        end
      end
      
      def instantiate_second_pass
        @rule_set.setComplete
        @rule_set.processMultDescKRRRs
      end
      
      def instantiate_third_pass
        #CustomLogger.info ("!!!!!!!!!!Generating search paths for: " + @rule_set.ident) 
        @rule_set.generateSecondaryAndMainRules
      end
    
    end

    # BootstrapRuleSet
    
    # TODO: remove BootstrapRuleSet class if unused
    class BootstrapRuleSet < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ Structure,
                                BPVFunctions,
                                Descriptions ]
      self.make_index = true
    end

    # RepositorySetp contents
    # SOC contents
  
    class HasGroupDomain < Line
      self.arg_opts = [[URI]]
      include FirstArgIsURI 
    end
  
    class BindSOCToRuleSet < Line
      self.arg_opts = [[Identifier]]
      
      def ident
        args[0].val
      end      
    end
  
    class MainLevel < Line
      self.arg_opts = [[]]
    end
  
    class SecondaryLevel < Line
      self.arg_opts = [[]]
    end

    class Internal < Line
      self.arg_opts = [[]]
    end
  
    class Rm < Line
      self.arg_opts = [[Identifier]]
    end
  
    class RequiredMembers < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [Rm]
    end

    class GroupInSearchResults < Line
      self.arg_opts = [[]]
    end

    class ArchivalRoot < Line
      self.arg_opts = [[]]
    end
    
    class SOC < Section
      include NameAndComment
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ MultilingualText,
                                Comment,
                                HasGroupDomain,
                                BindToRuleSet,
                                BindSOCToRuleSet, 
                                MainLevel,
                                SecondaryLevel,
                                Internal,
                                RequiredMembers,
                                Hardcoded,
                                GroupInSearchResults,
                                ArchivalRoot ]
      self.make_index = true
      include Java::MxOrgPescadorDefinitionsfiles::SOCEl  
      java_import 'mx.org.pescador.krmodel.operations.DOModifier'
      java_import 'mx.org.pescador.krmodel.rules.RuleManager'
     
      def instantiate_first_pass
        @realm = @file.realm
        hardcoded = contained(Hardcoded)
        soc_ruleset_el = contained(BindSOCToRuleSet)
        
        if hardcoded
          @soc = @realm.repositoryArea().soc(@id.val)
          hardcoded.done
        else 
          if soc_ruleset_el
            soc_ruleset = RuleManager.getRuleSet(soc_ruleset_el.ident, @realm)
            @soc = DOModifier.generateSOC(@id.val, @realm, soc_ruleset)
          else
            @soc = DOModifier.generateSOC(@id.val, @realm)
          end
        end
        # TODO: Throw error, or at least a warning, if there is no BindToRuleSet in the section
        rule_set_id = contained(BindToRuleSet).ident
        rule_set = RuleManager.getRuleSet(rule_set_id, @realm)
        @soc.setMembersRSBinding(rule_set)
        
        if contained(MainLevel)
          @soc.setMainLevel
        elsif contained(SecondaryLevel)
          @soc.setSecondaryLevel
        elsif contained(Internal)
          @soc.setInternal          
        else
          raise "No level set for this SOC: " + @soc.nodeToString
        end
        
        if contained(GroupInSearchResults)
          @soc.setGroupInSearchResults
        end
        
        if contained(ArchivalRoot)
          @soc.setArchivalRoot(true)
        end
        # TODO: Implement RequiredMembers, graph more stuff, set Def file element for Java obj
        # TODO: Set contained elements as done

      end
      
      def instantiate_second_pass
        java_import 'mx.org.pescador.krmodel.graphelements.Graph'
        
        @soc.performIndividualBinding

        # TODO: Throw error if there is no group domain
        has_group_domain = contained(HasGroupDomain)
        graph_part = @realm.getGraphPart(has_group_domain.prefix)
        cls = Graph.getConcreteCls(has_group_domain.localURIPart, graph_part)
        @soc.setGroupDomain(cls)
        add_name_and_comment(@soc)
        @soc.writeData
        @soc.setOpts
        self.done
      end
      
    end
  
    class RepositorySetup < Section
      self.section_id_opts = [nil]
      self.allowed_contents = [SOC]
    end
  
    class DefinitionSet < Section
      self.section_id_opts = [Identifier]
      self.allowed_contents = [ Vocabulary, 
                                RuleSet,
                                BootstrapRuleSet,
                                RepositorySetup]
    end
     
  end
end
