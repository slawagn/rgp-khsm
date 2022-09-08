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

  # группа тестов для незалогиненного юзера (Анонимус)
  context 'Anonymous user' do
    def expect_redirect_to_login
      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    def expect_game_to_be_nil
      game = assigns(:game)
      expect(game).to be_nil
    end

    # из экшена show анона посылаем
    it "can't access #show" do
      # вызываем экшен
      get :show, id: game_w_questions.id
      # проверяем ответ
      expect_redirect_to_login
    end

    it "can't create game" do
      post :create

      expect_game_to_be_nil
      expect_redirect_to_login
    end

    it "can't give an answer" do
      put :answer,
        id:     game_w_questions.id,
        letter: game_w_questions.current_game_question.correct_answer_key

      expect(game_w_questions.current_level).to be(0)

      expect_game_to_be_nil
      expect_redirect_to_login
    end

    it "can't take money" do
      game_w_questions.update(current_level: 2)
      put :take_money, id: game_w_questions.id

      expect(game_w_questions.finished?).to be_falsey

      expect_game_to_be_nil
      expect_redirect_to_login
    end

    it "can't get help" do
      put :help,
        id:     game_w_questions.id,
        letter: game_w_questions.current_game_question.correct_answer_key

      expect(game_w_questions.audience_help_used).to be_falsey

      expect_game_to_be_nil
      expect_redirect_to_login
    end
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'Usual user' do
    # перед каждым тестом в группе
    before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    # юзер может создать новую игру
    it 'creates game' do
      # сперва накидаем вопросов, из чего собирать новую игру
      generate_questions(15)

      post :create
      game = assigns(:game) # вытаскиваем из контроллера поле @game

      # проверяем состояние этой игры
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      # и редирект на страницу этой игры
      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    # юзер видит свою игру
    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)

      expect(response.status).to eq(200) # должен быть ответ HTTP 200
      expect(response).to render_template('show') # и отрендерить шаблон show
    end

    # юзер отвечает на игру корректно - игра продолжается
    it 'answers correct' do
      # передаем параметр params[:letter]
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
    end

    # тест на отработку "помощи зала"
    it 'uses audience help' do
      # сперва проверяем что в подсказках текущего вопроса пусто
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be_falsey

      # фигачим запрос в контроллен с нужным типом
      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)

      # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
      expect(game.finished?).to be_falsey
      expect(game.audience_help_used).to be_truthy
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response).to redirect_to(game_path(game))
    end
  end

  describe '#show' do
    context "when trying to see somebody else's game" do
      it 'redirects to root' do
        somebody_elses_game = FactoryGirl.create(:game_with_questions)

        sign_in user
        get :show, id: somebody_elses_game.id

        expect(response.status).not_to eq(200)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be
      end
    end
  end

  describe '#take_money' do
    let(:level) { 2 }

    it 'finishes the game with appropriate prize' do
      sign_in user
      game_w_questions.update(current_level: level)
      put :take_money, id: game_w_questions.id

      game = assigns(:game)
      expect(game.finished?).to be_truthy
      expect(game.prize).to eq(Game::PRIZES[level - 1])
      expect(user.reload.balance).to eq(Game::PRIZES[level - 1])
      expect(response).to redirect_to user_path(user)
      expect(flash[:warning]).to be
    end
  end

  describe '#create' do
    context 'when a game in progress already exists' do
      it 'redirects to an already existing game' do
        sign_in user

        expect(game_w_questions.finished?).to be_falsey

        expect { post :create }.to change(Game, :count).by(0)

        game = assigns(:game)
        expect(game).to be_nil

        expect(response).to redirect_to game_path(game_w_questions.id)
        expect(flash[:alert]).to be
      end
    end
  end
end
