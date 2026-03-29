require File.expand_path("system_test", __dir__)

class MlModelTest < SystemTest
  def test_views_ml_models_page
    sign_in

    visit "/ml_models"
    assert_text "ML Models"
    assert_text "Train New Model"
  end

  def test_activate_ml_model
    ml_model = ml_models(:one)
    sign_in

    visit "/ml_models"

    click "Activate"

    assert_text "activated"
  end

  def test_deactivate_ml_model
    ml_model = ml_models(:two)
    sign_in

    visit "/ml_models"

    click "Deactivate"

    assert_text "deactivated"
  end

  def test_train_form_is_present
    sign_in

    visit "/ml_models"
    assert_selector "select[name='pair']"
    assert_selector "select[name='days']"
    assert_text "Start Training"
  end
end
