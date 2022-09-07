# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryGirl.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end


  # тесты на основную игровую логику
  context 'game mechanics' do

    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end
  end

  describe '#take_money!' do
    context 'when the first question has been answered correctly' do
      it 'finishes game with appropriate score' do
        game_w_questions.answer_current_question!(
          game_w_questions.current_game_question.correct_answer_key
        )
        expect(game_w_questions.status).to eq(:in_progress)

        game_w_questions.take_money!
        expect(game_w_questions.status).to eq(:money)
        expect(game_w_questions.finished?).to be_truthy
        expect(game_w_questions.prize).to eq(Game::PRIZES.first)

        expect(user.balance).to eq(Game::PRIZES.first)
      end
    end
  end

  describe '#status' do
    subject { game_w_questions.status }

    before(:each) do |test|
      unless test.metadata[:unfinished_game]
        game_w_questions.finished_at = Time.now
        expect(game_w_questions.finished?).to be_truthy
      end
    end

    context 'when the game is not finished' do
      it 'should be :in_progress', :unfinished_game do
        is_expected.to eq(:in_progress)
      end
    end

    context 'when the game is lost' do
      it 'should be :fail' do
        game_w_questions.is_failed = true
        is_expected.to eq(:fail)
      end
    end

    context 'when a timeout has been reached' do
      it 'should be :timeout' do
        game_w_questions.finished_at += Game::TIME_LIMIT
        game_w_questions.is_failed = true
        is_expected.to eq(:timeout)
      end
    end

    context 'when the game has been won' do
      it 'should be :won' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
        is_expected.to eq(:won)
      end
    end

    context 'when money has been taken' do
      it 'should be :money' do
        is_expected.to eq(:money)
      end
    end
  end

  describe '#current_game_question' do
    let(:question) { game_w_questions.current_game_question }

    it 'should return question of corresponding level' do
      expect(question.level).to eq(game_w_questions.current_level)
    end
  end

  describe '#previous_level' do
    it 'should return previous level' do
      expect(game_w_questions.previous_level).to eq(game_w_questions.current_level - 1)
    end
  end
end
