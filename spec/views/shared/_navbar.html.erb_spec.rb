require 'rails_helper'

RSpec.describe "shared/_navbar.html.erb" do
  it "should have a link to vocabularies" do
    render
    expect(rendered).to have_link("Vocabularies", :href => vocabularies_path)
  end
  context "when logged in" do
    let(:user) { User.create(:email => 'blah@blah.com', :password => "admin123", :role => "admin", :institution => "Oregon State University", :name => "Test") }

    before do
      sign_in(user) if user
    end
    it "should display a link to import external RDF  " do
      render
      expect(rendered).to have_link "Import External RDF", :href => "/import_rdf"
    end
  end
  context "when not logged in" do
    it "should not display link to import external RDF" do
      render
      expect(rendered).to_not have_link "Import External RDF", :href => "/import_rdf"
    end
  end
end
