class TermsController < AdminController
  delegate :term_form_repository, :term_repository, :vocabulary_repository, :to => :injector
  delegate :deprecate_term_form_repository, :to => :deprecate_injector
  rescue_from ActiveTriples::NotFound, :with => :render_404
  include GitInterface

  before_filter :skip_render_on_cached_page, only: :show
  caches_page :show
  skip_before_filter :require_admin
  before_filter :require_editor, :except => [:index, :show]

  def show
    @term = find_term

    # TODO: replace functionality, this causes memory leak and slowness currently.
    #@term.commit_history = get_history(@term.id)
    respond_to do |format|
      format.html
      format.nt { render body: @term.full_graph.dump(:ntriples), :content_type => Mime::NT }
      format.jsonld { render body: @term.full_graph.dump(:jsonld, standard_prefixes: true), :content_type => Mime::JSONLD }
    end
  end

  def new
    @term = term_form_repository.new
    @vocabulary = find_vocabulary
  end

  def create
    @vocabulary = find_vocabulary
    combined_id = CombinedId.new(params[:vocabulary_id], term_params[:id])
    term_form = term_form_repository.new(combined_id, params[:term_type].constantize)
    term_form.attributes = vocab_params.except(:id)
    term_form.set_languages(params[:vocabulary])
    term_form.set_modified
    term_form.set_issued
    if term_form.is_valid?
      term_form.add_resource
      triples = term_form.sort_stringify(term_form.full_graph)
      check = rugged_create(combined_id.to_s, triples, "creating")
      if check
        flash[:notice] = "#{combined_id.to_s} has been saved and added to the review queue."
      else
        flash[:notice] = "Something went wrong, please notify a systems administrator."
      end
      redirect_to term_path(:id => params[:vocabulary_id])
    else
      @term = term_form
      render "new"
    end
  end

  def edit
    @term = term_form_repository.find(params[:id])
    @disable = true
  end

  def update
    edit_term_form = term_form_repository.find(params[:id])
    edit_term_form.attributes = vocab_params
    edit_term_form.set_languages(params[:vocabulary])
    edit_term_form.set_modified
    if edit_term_form.is_valid?
      triples = edit_term_form.sort_stringify(edit_term_form.full_graph)
      check = rugged_create(params[:id], triples, "updating")
      if check
        flash[:notice] = "#{params[:id]} has been saved and added to the review queue."
      else
       flash[:notice] = "Something went wrong, please notify a systems administrator."
      end
      id_parts = params[:id].split("/")
      redirect_to term_path(:id => id_parts[0])
    else
      @term = edit_term_form
      render "edit"
    end
  end

  def review_update
    if Term.exists? params[:id]
      term_form = term_form_repository.find(params[:id])
      term_form.attributes = vocab_params
      action = "edit"
    else
      term_form = term_form_repository.new(params[:id], params[:term_type].constantize)
      term_form.attributes = vocab_params.except(:id)
      term_form.add_resource
      action = "new"
    end
    term_form.set_languages(params[:vocabulary])
    term_form.set_modified
    term_form.reset_issued(params[:issued])

    if term_form.is_valid?
      triples = term_form.sort_stringify(term_form.full_graph)
      check = rugged_create(params[:id], triples, "updating")
      if check
        flash[:notice] = "Changes to #{params[:id]} have been saved and added to the review queue."
      else
        flash[:notice] = "Something went wrong, please notify a systems administrator."
      end
      redirect_to review_queue_path
    else
      @term = term_form
      render action
    end
  end

  def mark_reviewed
    if Term.exists? params[:id]
      e_params = edit_params(params[:id])
      term_form = term_form_repository.find(params[:id])
      term_form.attributes = ParamCleaner.call(e_params[:vocabulary].reject{|k,v| k==:language})
      term_form.set_languages(e_params[:vocabulary])
      @term = term_form
    else
      @term = reassemble(params[:id])
      type = Term
      if !@term.type.blank?
        @term.type.each do |t|
          if t.to_s != "http://www.w3.org/2000/01/rdf-schema#Resource" && t.to_s != "http://www.w3.org/2004/02/skos/core#Concept"
            type = t.object[:fragment].constantize
            break
          end
        end
      end
      term_form = TermForm.new(@term, StandardRepository.new(nil, type))
    end
    branch_commit = rugged_merge(params[:id])
    if branch_commit != 0
      if term_form.save
        expire_page action: 'show', id: params[:id], format: :html
        expire_page action: 'show', id: params[:id], format: :jsonld
        expire_page action: 'show', id: params[:id], format: :nt
        expire_page action: 'show', id: @term.term_uri_vocabulary_id, format: :html if @term.term_id.hasParent?
        expire_page action: 'show', id: @term.term_uri_vocabulary_id, format: :jsonld if @term.term_id.hasParent?
        expire_page action: 'show', id: @term.term_uri_vocabulary_id, format: :nt if @term.term_id.hasParent?
        rugged_delete_branch(params[:id])
        flash[:notice] = "#{params[:id]} has been saved and is ready for use."
        redirect_to review_queue_path
      else
        rugged_rollback(branch_commit)
        flash[:notice] = "Something went wrong, and term was not saved."
        redirect_to review_queue_path
      end
    else
      flash[:notice] = "Something went wrong, please notify a system administrator."
      redirect_to review_queue_path
    end
  end

  def deprecate_only
    edit_term_form = deprecate_term_form_repository.find(params[:id])
    edit_term_form.is_replaced_by = vocab_params[:is_replaced_by]
    if edit_term_form.is_valid?
      triples = edit_term_form.sort_stringify(edit_term_form.full_graph)
      check = rugged_create(params[:id], triples, "updating")
      if check
        flash[:notice] = "Changes to #{params[:id]} have been saved and added to the review queue."
      else
        flash[:notice] = "Something went wrong, please notify a systems administrator."
      end
      id_parts = params[:id].split("/")
      redirect_to term_path(:id => id_parts[0])
    else
      @term = edit_term_form
      render "deprecate"
    end
  end

  def deprecate
    @term = term_form_repository.find(params[:id])
  end

  private

  def term_params
    ParamCleaner.call(params[:term])
  end

  def vocab_params
    ParamCleaner.call(params[:vocabulary])
  end

  def injector
    @injector ||= TermInjector.new(params)
  end

  def deprecate_injector
    @injector ||= DeprecateTermInjector.new(params)
  end

  def find_term
    term_repository.find(params[:id])
  end

  def find_vocabulary
    vocabulary_repository.find(params[:vocabulary_id])
  end

  def render_404
    respond_to do |format|
      format.html { render "terms/404", :status => 404 }
      format.all { render nothing: true, status: 404 }
    end
  end

  def vocabulary
    @vocabulary ||= Vocabulary.find(params[:vocabulary_id])
  end

end
