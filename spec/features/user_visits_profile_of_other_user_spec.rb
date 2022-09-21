require 'rails_helper'

RSpec.feature 'USER visits profile of other user', type: :feature do
  let(:current_user) { FactoryGirl.create :user }
  let(:other_user) { FactoryGirl.create :user }
  let(:create_games) {
    FactoryGirl.create(:game, user: other_user,
      created_at:  Time.parse('2016.10.09, 13:00'),
      finished_at: Time.parse('2016.10.09, 13:10'),
      prize: 1_000_000,
      current_level: 15)
    FactoryGirl.create(:game, user: other_user,
      created_at:  10.minutes.ago
    )
  }

  before(:each) do
    login_as current_user
    create_games
  end

  scenario 'success' do
    visit user_path(other_user)
    expect(page).not_to have_content 'Сменить имя и пароль'
    expect(page).to have_current_path '/users/2'
    expect(page).to have_content 'победа'
    expect(page).to have_content '09 окт., 13:00'
    expect(page).to have_content '1 000 000 ₽'
    expect(page).to have_content '15'
  end
end
