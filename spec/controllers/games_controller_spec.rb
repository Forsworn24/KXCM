require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { create(:user) }
  # админ
  let(:admin) { create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами  и !юзером!
  let(:game_w_questions) { create(:game_with_questions, user: user) }

  # создаем новую игру, юзер не прописан, будет создан фабрикой новый
  let(:alien_game) { create(:game_with_questions) }

  context 'Anon' do
    it 'kick from #show' do
      get :show, id: game_w_questions.id
      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end
  end
  

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'Usual user' do
    before(:each) do
      sign_in user
    end
    
    it 'creater game' do
      generate_questions(60)

      post :create
      
      game = assigns(:game)

      # проверяем состояние этой игры
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)

      expect(response).to redirect_to game_path(game)
      expect(flash[:notice]).to be
    end

    # юзер видит свою игру
    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      expect(response.status).to eq 200

      expect(response).to render_template('show')
    end

    # пользователь ответил правильно на вопрос и контроллер это обработает
    it 'answer correct' do
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key

      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be_truthy
    end

  end

end
