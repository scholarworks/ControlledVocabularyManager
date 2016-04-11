require 'rails_helper'

RSpec.describe PredicatesController do
  let(:logged_in) { true}
  before do
    allow(controller).to receive(:check_auth).and_return(true) if logged_in
  end

  describe "Get 'new'" do
    let(:result) { get 'new' }
    before do
      result
    end
    it "should be successful" do
      expect(result).to be_success
    end
    it "assigns @predicate" do
      assigned = assigns(:predicate)
      expect(assigned).to be_kind_of PredicateForm
      expect(assigned).to be_new_record
    end
    it "renders new" do
      expect(result).to render_template("new")
    end
  end
  describe "GET 'edit'" do
    let(:predicate_form) { instance_double("PredicateForm") }
    let(:predicate) { predicate_mock }
    before do
      allow_any_instance_of(PredicateFormRepository).to receive(:find).and_return(predicate_form)
      allow(predicate).to receive(:attributes=)
      get 'edit', :id => predicate.id
    end
    it "should assign @term" do
      expect(assigns(:term)).to eq predicate_form
    end
    it "should render edit" do
      expect(response).to render_template 'edit'
    end
  end

  describe "PATCH 'update'" do
    let(:predicate) { predicate_mock }
    let(:predicate_form) { PredicateForm.new(SetsAttributes.new(predicate), Predicate) }
    let(:params) do
      {
        :comment => ["Test"],
        :label => ["Test"],
        :language => {
          :label => ["en"],
          :comment => ["en"]
        }
      }
    end
    let(:persist_success) { true }

    before do
      allow_any_instance_of(PredicateFormRepository).to receive(:find).and_return(predicate_form)
      allow(predicate).to receive(:blacklisted_language_properties).and_return([:id, :issued, :modified])
      allow(predicate).to receive(:attributes=)
      allow(predicate).to receive(:persist!).and_return(persist_success)
      allow(predicate_form).to receive(:valid?).and_return(true)
      allow(predicate).to receive(:attributes).and_return(params)
      patch :update, :id => predicate.id, :predicate => params, :vocabulary => params
    end

    context "when the fields are edited" do
      it "should update the properties" do
         expect(predicate).to have_received(:attributes=).with({:comment=>[RDF::Literal("Test", :language => :en)], :label=>[RDF::Literal("Test", :language => :en)]}).exactly(1).times
      end
      it "should redirect to the updated term" do
        expect(response).to redirect_to("/ns/#{predicate.id}")
      end
      context "and there are blank fields" do
        let(:params) do
          {
            :comment => [""],
            :label => ["Test"],
            :language => {
              :label => ["en"]
            }
          }
        end
        it "should ignore them" do
          expect(predicate).to have_received(:attributes=).with(:comment => [], :label => ["Test"])
        end
      end
    end

    context "when the fields are edited and the update fails" do
      let(:persist_success) { false }
      it "should show the edit form" do
        expect(assigns(:term)).to eq predicate_form
        expect(response).to render_template("edit")
      end
    end
  end
  describe "GET 'index'" do
    context "when there are predicates" do
      let(:injector) { PredicateInjector.new }
      let(:predicate) {
        p = Vocabulary.new("mypred")
        p.label = "my pred label"
        p
      }

      before do
        allow(predicate).to receive(:repository).and_return(Predicate.new.repository)
        allow(AllVocabsQuery).to receive(:call).and_return([predicate])
      end
      it "should set @predicates to all preds" do
        get :index
        expect(assigns(:predicates)).to eq [predicate]
      end
    end
    it "should be successful" do
      get :index

      expect(response).to be_success
    end
    it "renders index" do
      get :index

      expect(response).to render_template "index"
    end
    context "when not logged in" do
      let(:logged_in) { false }
      it "should not redirect" do
        expect(response).not_to be_redirect
      end
    end
  end

  describe "POST create" do
    let(:predicate_params) do
      {
        :label => ["Test1"],
        :comment => ["Test2"],
        :language => {
            :label => ["en"],
            :comment => ["en"]
          }
      }
    end
    let(:predicate) { instance_double("Predicate") }
    let(:predicate_form) { PredicateForm.new(SetsAttributes.new(predicate), Predicate) }
    let(:result) { post 'create', :predicate => predicate_params, :vocabulary => predicate_params }
    let(:save_success) { true }
    before do
      allow_any_instance_of(PredicateFormRepository).to receive(:new).and_return(predicate_form)
      allow(predicate_form).to receive(:save).and_return(save_success)
      allow(predicate).to receive(:blacklisted_language_properties).and_return([:id, :issued, :modified])
      allow(predicate).to receive(:id).and_return("test")
      allow(predicate).to receive(:attributes=)
      allow(predicate).to receive(:attributes).and_return(predicate_params)
      post 'create', :predicate => predicate_params, :vocabulary => predicate_params
    end
    it "should save term form" do
      expect(predicate_form).to have_received(:save)
    end

    context "when all goes well" do
      it "should redirect to the term" do
        expect(response).to redirect_to("/ns/#{predicate.id}")
      end
    end

  end

end