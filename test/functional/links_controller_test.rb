require 'test_helper'

class LinksControllerTest < ActionController::TestCase
  def test_create_invalid
    Link.any_instance.stubs(:valid?).returns(false)
    post :create
    assert_template 'new'
  end

  def test_create_valid
    Link.any_instance.stubs(:valid?).returns(true)
    post :create
    assert_redirected_to root_url
  end

  def test_destroy
    link = Link.first
    delete :destroy, :id => link
    assert_redirected_to root_url
    assert !Link.exists?(link.id)
  end
end
