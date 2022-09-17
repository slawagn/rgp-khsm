require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  let(:user) { FactoryGirl.build_stubbed(:user, name: 'Имярек', balance: 1000) }
  let(:other_user) { FactoryGirl.build_stubbed(:user, name: 'Другой') }
  let(:games) { [FactoryGirl.build_stubbed(:game)] }

  context 'when user is set' do
    before do
      assign(:user, user)
    end

    it "renders user's name" do
      render
      expect(rendered).to match 'Имярек'
    end

    context 'when the user is logged in' do
      before do
        allow(view).to receive(:current_user).and_return(user)
      end

      context 'and visiting own page' do
        it 'renders edit profile button' do
          render
          expect(rendered).to match('Сменить имя и пароль')
        end
      end

      context "and visiting somebody else's page" do
        before do
          assign(:user, other_user)
        end

        it 'does not render edit profile button' do
          render
          expect(rendered).not_to match('Сменить имя и пароль')
        end
      end
    end

    context 'when there is a game to be rendered' do
      before do
        assign(:games, games)
        stub_template('users/_game.html.erb' => 'User game goes here')
      end

      it 'renders _game partials' do
        render
        expect(rendered).to match('User game goes here')
      end
    end
  end
end
