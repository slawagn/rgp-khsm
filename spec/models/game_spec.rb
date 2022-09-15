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
      it 'returns :in_progress', :unfinished_game do
        is_expected.to eq(:in_progress)
      end
    end

    context 'when the game is lost' do
      it 'returns :fail' do
        game_w_questions.is_failed = true
        is_expected.to eq(:fail)
      end
    end

    context 'when a timeout has been reached' do
      it 'returns :timeout' do
        game_w_questions.finished_at += Game::TIME_LIMIT
        game_w_questions.is_failed = true
        is_expected.to eq(:timeout)
      end
    end

    context 'when the game has been won' do
      it 'returns :won' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
        is_expected.to eq(:won)
      end
    end

    context 'when money has been taken' do
      it 'returns :money' do
        is_expected.to eq(:money)
      end
    end
  end

  describe '#current_game_question' do
    it 'returns question of corresponding level' do
      expect(game_w_questions.current_game_question)
        .to eq(game_w_questions.game_questions.first)
    end
  end

  describe '#previous_level' do
    it 'returns previous level' do
      expect(game_w_questions.previous_level).to eq(game_w_questions.current_level - 1)
    end
  end

  describe '#answer_current_question!' do
    let(:give_incorrect_answer) do
      game_w_questions.answer_current_question!(incorrect_answer_key)
    end
    let(:give_correct_answer) do
      game_w_questions.answer_current_question!(correct_answer_key)
    end
    let(:incorrect_answer_key) do
      (current_question.variants.keys - [current_question.correct_answer_key]).first
    end
    let(:correct_answer_key) { current_question.correct_answer_key }
    let(:current_question) { game_w_questions.current_game_question }

    context 'when an incorrect answer is given' do
      it 'finishes the game with failure' do
        give_incorrect_answer

        expect(game_w_questions.finished?).to be_truthy
        expect(game_w_questions.status).to eq(:fail)
      end
    end

    context 'when the correct answer is given' do
      context 'and the question is a regular one' do
        it 'increases level by 1' do
          initial_level = game_w_questions.current_level

          give_correct_answer

          expect(game_w_questions.finished?).to be_falsey
          expect(game_w_questions.previous_level).to eq(initial_level)
          expect(game_w_questions.status).to eq(:in_progress)
        end
      end

      context 'and the question answered was the last one' do
        it 'finishes the game as won' do
          game_w_questions.current_level = Question::QUESTION_LEVELS.max

          give_correct_answer

          expect(game_w_questions.finished?).to be_truthy
          expect(game_w_questions.status).to eq(:won)
        end
      end

      context 'but the timeout is reached' do
        it 'returns false and finishes the game' do
          game_w_questions.created_at = Time.now - Game::TIME_LIMIT

          expect(give_correct_answer).to be_falsey
          expect(game_w_questions.finished?).to be_truthy
          expect(game_w_questions.status).to eq(:timeout)
        end
      end
    end
  end
end
