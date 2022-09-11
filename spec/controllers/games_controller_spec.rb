# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryGirl.create(:user) }
  # админ
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  describe '#create' do
    context 'when the user is anonymous' do
      before do
        post :create
        @game = assigns(:game)
      end

      it 'does not create a game' do
        expect(@game).to be_nil
      end

      it 'redirects to login page' do
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'sets flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when the user is logged in' do
      before { sign_in user }

      context 'and no game in progress exists for current user' do
        before do
          generate_questions(15)

          post :create
          @game = assigns(:game)
        end

        it 'creates a game for current user' do
          expect(@game.finished?).to be_falsey
          expect(@game.user).to eq(user)
        end

        it 'redirects to the game page' do
          expect(response).to redirect_to(game_path(@game))
        end

        it 'shows flash' do
          expect(flash[:notice]).to be
        end
      end

      context 'and a game in progress already exists' do
        before do
          expect(game_w_questions.finished?).to be_falsey
          expect { post :create }.to change(Game, :count).by(0)
          @game = assigns(:game)
        end

        it 'does not create a new game' do
          expect(@game).to be_nil
        end

        it 'redirects to game path' do
          expect(response).to redirect_to game_path(game_w_questions.id)
        end

        it 'sets flash' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#show' do
    context 'when the user is anonymous' do
      before do
        get :show, id: game_w_questions.id
        @game = assigns(:game)
      end

      it 'does not show a game' do
        expect(@game).to be_nil
      end

      it 'redirects to login page' do
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'sets flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when the user is logged in' do
      before { sign_in user }

      context 'and trying to see their own game' do
        before do
          get :show, id: game_w_questions.id
          @game = assigns(:game)
        end

        it 'shows a game belonging to current user' do
          expect(@game.finished?).to be false
          expect(@game.user).to eq(user)
        end

        it 'responds with OK' do
          expect(response.status).to eq(200)
        end

        it 'renders show template' do
          expect(response).to render_template('show')
        end
      end

      context "and trying to see somebody else's game" do
        before do
          somebody_elses_game = FactoryGirl.create(:game_with_questions)

          get :show, id: somebody_elses_game.id
        end

        it 'redirects to root path' do
          expect(response.status).not_to eq(200)
          expect(response).to redirect_to(root_path)
        end

        it 'sets flash' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#answer' do
    context 'when the user is anonymous' do
      before do
        put :answer,
          id:     game_w_questions.id,
          letter: game_w_questions.current_game_question.correct_answer_key

        @game = assigns(:game)
      end

      it 'does not set a game' do
        expect(@game).to be_nil
      end

      it 'redirects to login page' do
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'sets flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when the user is logged in' do
      before { sign_in user }

      context 'and answering the question for their own game' do
        before do
          put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
          @game = assigns(:game)
        end

        it 'continues the game' do
          expect(@game.finished?).to be_falsey
          expect(@game.current_level).to be > 0
        end

        it 'redirects do game path' do
          expect(response).to redirect_to(game_path(@game))
        end

        it 'does not show flash' do
          expect(flash.empty?).to be true
        end
      end
    end
  end

  describe '#take_money' do
    context 'when the user is anonymous' do
      before do
        game_w_questions.update(current_level: 2)
        put :take_money, id: game_w_questions.id

        @game = assigns(:game)
      end

      it 'does not finish a game' do
        expect(game_w_questions.finished?).to be false
      end

      it 'does not set a game' do
        expect(@game).to be_nil
      end

      it 'redirects to login page' do
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'sets flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when the user is logged in' do
      before { sign_in user }

      context 'and finishing their own game' do
        let(:level) { 2 }

        before do
          game_w_questions.update(current_level: level)
          put :take_money, id: game_w_questions.id
          @game = assigns(:game)
        end

        it 'finishes the game' do
          expect(@game.finished?).to be true
        end

        it 'sets the game prize' do
          expect(@game.prize).to eq(Game::PRIZES[level - 1])
        end

        it 'increases user balance by the prize amount' do
          expect(user.reload.balance).to eq(@game.prize)
        end

        it 'redirects to user path' do
          expect(response).to redirect_to user_path(user)
        end

        it 'sets flash' do
          expect(flash[:warning]).to be
        end
      end
    end
  end

  describe '#help' do
    context 'when the user is anonymous' do
      before do
        put :help,
          id:     game_w_questions.id,
          letter: game_w_questions.current_game_question.correct_answer_key

        @game = assigns(:game)
      end

      it 'does not use help' do
        expect(game_w_questions.audience_help_used).to be false
      end

      it 'does not set a game' do
        expect(@game).to be_nil
      end

      it 'redirects to login page' do
        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'sets flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when the user is logged in' do
      before { sign_in user }

      context 'and getting help for their own game' do
        before do
          expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
          expect(game_w_questions.audience_help_used).to be false

          put :help, id: game_w_questions.id, help_type: :audience_help
          @game = assigns(:game)
        end

        it 'does not finish the game' do
          expect(@game.finished?).to be false
        end

        it 'marks help as used' do
          expect(@game.audience_help_used).to be true
        end

        it 'sets the help hash' do
          expect(@game.current_game_question.help_hash[:audience_help]).to be
          expect(@game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
        end

        it 'redirects to game path' do
          expect(response).to redirect_to(game_path(@game))
        end
      end
    end
  end
end
