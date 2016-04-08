class VocabularyInjector < Struct.new(:params)
  def vocabulary_form_repository
    VocabularyFormRepository.new(decorators)
  end

  def vocabulary_repository
    @vocabulary_repository ||= StandardRepository.new(decorators, nil)
  end

  def all_vocabs_query
    -> { AllVocabsQuery.call(sparql_client, vocabulary_repository, Vocabulary.type) }
  end
  
  def sparql_client
    sparql = SPARQL::Client.new("#{Settings.marmotta.url}/sparql/select")
    if Rails.env == "test"
      sparql = sparql.select.graph("#{Settings.marmotta.url}/context/test")
    end
    @sparql_client ||= sparql
  end

  def child_node_finder
    @child_node_finder ||= ChildNodeFinder.new(StandardRepository.new, sparql_client)
  end

  def params
    super || {}
  end

  def decorators
    DecoratorList.new(
      SetsAttributes,
      SetsModified,
      SetsIssued,
      DecoratorWithArguments.new(TermWithChildren, child_node_finder)
    )
  end

end
