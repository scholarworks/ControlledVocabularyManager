class TermCreatePage < Struct.new(:vocabulary_id)
  include Capybara::DSL

  def self.id
    "TestTerm"
  end

  def visible?
    has_content? "Create New Term"
  end

  def create
    fill_in "ID", :with => self.id
    fill_in "vocabulary[label][]", :with => "Test label"
    fill_in "vocabulary[comment][]", :with => "Test comment"
    find(:xpath, "//*[@name='commit']").trigger('click')
    sleep 2
    TermShowPage.new("#{vocabulary_id}/#{self.id}")
  end
end
