# (c) goodprogrammer.ru

require 'rails_helper'

# Тестовый сценарий для модели игрового вопроса,
# в идеале весь наш функционал (все методы) должны быть протестированы.
RSpec.describe GameQuestion, type: :model do
  # задаем локальную переменную game_question, доступную во всех тестах этого сценария
  # она будет создана на фабрике заново для каждого блока it, где она вызывается
  let(:game_question) { FactoryGirl.create(:game_question, a: 2, b: 1, c: 4, d: 3) }

  describe '#variants' do
    it 'shows answers in correct order' do
      expect(game_question.variants).to eq(
        {
          'a' => game_question.question.answer2,
          'b' => game_question.question.answer1,
          'c' => game_question.question.answer4,
          'd' => game_question.question.answer3
        }
      )
    end
  end

  describe '#answer_correct?' do
    it 'tells that correct answer is correct' do
      expect(game_question.answer_correct?('b')).to be_truthy
    end
  end

  # help_hash у нас имеет такой формат:
  # {
  #   fifty_fifty: ['a', 'b'], # При использовании подсказски остались варианты a и b
  #   audience_help: {'a' => 42, 'c' => 37 ...}, # Распределение голосов по вариантам a, b, c, d
  #   friend_call: 'Василий Петрович считает, что правильный ответ A'
  # }
  #

  describe '#add_audience_help' do
    before do
      expect(game_question.help_hash).not_to include(:audience_help)

      game_question.add_audience_help
    end

    it 'adds :audience_help to help_hash' do
      expect(game_question.help_hash).to include(:audience_help)

      ah = game_question.help_hash[:audience_help]
      expect(ah.keys).to contain_exactly('a', 'b', 'c', 'd')
    end
  end

  describe '#add_fifty_fifty' do
    before do
      expect(game_question.help_hash).not_to include(:fifty_fifty)

      game_question.add_fifty_fifty
    end

    it 'adds :fifty_fifty to help_hash' do
      expect(game_question.help_hash).to include(:fifty_fifty)

      ff = game_question.help_hash[:fifty_fifty]
      expect(ff).to include('b')
      expect(ff.size).to be 2
    end
  end

  describe '#text' do
    it 'is delegated to Question model' do
      expect(game_question.text).to  eq(game_question.question.text)
    end
  end

  describe '#level' do
    it 'is delegated to Question model' do
      expect(game_question.level).to  eq(game_question.question.level)
    end
  end

  describe '#correct_answer_key' do
    it 'returns character b' do
      expect(game_question.correct_answer_key).to eq('b')
    end
  end

  describe '#help_hash' do
    before do
      expect(game_question.help_hash).to be_empty

      game_question.help_hash[:helper1] = 'helper1 content'
      game_question.help_hash[:helper2] = 'helper2 content'
    end

    it 'saves to db' do
      expect(game_question.save).to be true
    end

    it 'loads from db' do
      expect(game_question.save).to be true
      hash_from_db = GameQuestion.find(game_question.id).help_hash

      expect(hash_from_db).to eq({helper1: 'helper1 content', helper2: 'helper2 content'})
    end
  end
end
