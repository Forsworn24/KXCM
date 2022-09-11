# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

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

  # тест на метод take_money
  # Моделируем ситуацию, когда имеет смысл брать деньги: игра началась и отвечен хотя бы один ответ. 
  # После этого используем метод и проверяем, что игра закончилась, а баланс игрока пополнился на соотв. сумму.
  context 'check take_money method' do
    it 'take_money! finishes the game' do
      # берем игру и отвечаем на текущий вопрос
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)
    
      # взяли деньги
      game_w_questions.take_money!
    
      prize = game_w_questions.prize
      expect(prize).to be > 0
    
      # проверяем что закончилась игра и пришли деньги игроку
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end
  end

  # группа тестов на проверку статуса игры
  context '.status' do
    # перед каждым тестом "завершаем игру"
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it ':won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it ':timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it ':money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end

  # в текущей игре мы еще не ответили ни на один вопрос
  # следовательно, ответ будет 
  describe '#current_game_question' do
    it 'return question without answer' do
      expect(game_w_questions.current_game_question).
        to eq game_w_questions.game_questions[0]
    end
  end

  #текущий левел - 0, предыдущий, соответственно - -1
  describe '#previous_level' do
    it 'return previous level game' do
      expect(game_w_questions.previous_level).to eq(-1)
    end
  end

  #группа тестов на метод модели answer_current_question
  describe '#answer_current_question!' do
    let(:question_with_answers) { game_w_questions.current_game_question }
    let(:wrong_answer) { %w[a b c d].reject { |answer| answer == question_with_answers.correct_answer_key }.sample }

    context 'when the answer is correct' do
      it 'return true if answer is correct' do
        q = game_w_questions.current_game_question
        expect(game_w_questions.answer_current_question!(q.correct_answer_key)).to be true
        expect(game_w_questions.finished?).to be false
        expect(game_w_questions.status).to eq :in_progress
      end
    end

    context "when the answer is not correct" do
      it 'return false not correct answer' do
        q = game_w_questions.current_game_question
        expect(game_w_questions.answer_current_question!(wrong_answer)).to be false
        expect(game_w_questions.finished?).to be true
        expect(game_w_questions.status).to eq :fail
      end
    end

    context "when the answer is given after the time for answer" do
      it 'return false on is timeout' do
        game_w_questions.created_at = 2.hours.ago
        q = game_w_questions.current_game_question
        expect(game_w_questions.answer_current_question!(q.correct_answer_key)).to be false
        expect(game_w_questions.finished?).to be true
        expect(game_w_questions.status).to eq :timeout
      end
    end

    context 'when the answer is last question' do
      it 'return true on correct answer last question' do
        game_w_questions.current_level = 14
        q = game_w_questions.current_game_question
        expect(game_w_questions.answer_current_question!(q.correct_answer_key)).to be true
        expect(game_w_questions.finished?).to be true
        expect(game_w_questions.status).to eq :won
      end
    end
  end
end
