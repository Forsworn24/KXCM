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
    
    # анонимный пользователь не может смотреть игру
    it 'kick from #show' do
      get :show, id: game_w_questions.id
      expect(response.status).not_to eq 200
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to be
    end
    
    # анонимный пользователь не может создать игру
    it 'kick from #create' do
      post :create

      game = assigns(:game)

      # пустая игра
      expect(game).to be_nil

      # статус не 200
      expect(response.status).not_to eq 200
      
      # редиректим на страницу игры
      expect(response).to redirect_to(new_user_session_path)

      # выводим ошибку
      expect(flash[:alert]).to be
    end

    # анонимный пользователь не может дать ответ
    it 'cant #answer' do
      # передаем параметр params[:letter]
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key

      # задаем игру
      game = assigns(:game)

      # пустрая игра
      expect(game).to be_nil

      # статус не 200
      expect(response.status).not_to eq(200)

      # редиректим на страницу игры
      expect(response).to redirect_to(new_user_session_path)

      # выводим ошибку
      expect(flash[:alert]).to be
    end
    
    # анонимный пользователь не может забрать деньги
    it 'cant #take_money' do
      # вручную поднимем уровень вопроса до выигрыша 200
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id

      game = assigns(:game)

      # пустрая игра
      expect(game).to be_nil

      # статус не 200
      expect(response.status).not_to eq(200)

      # редиректим на страницу игры
      expect(response).to redirect_to(new_user_session_path)

      # выводим ошибку
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

    it '#show alien game' do
      # создаем новую игру, юзер не прописан, будет создан фабрикой новый
      alien_game = create(:game_with_questions)
    
      # пробуем зайти на эту игру текущий залогиненным user
      get :show, id: alien_game.id
    
      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    # юзер берет деньги
    it 'takes money' do
      # вручную поднимем уровень вопроса до выигрыша 200
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id
      game = assigns(:game)
      expect(game.finished?).to be_truthy
      expect(game.prize).to eq(200)

      # пользователь изменился в базе, надо в коде перезагрузить!
      user.reload
      expect(user.balance).to eq(200)

      expect(response).to redirect_to(user_path(user))
      expect(flash[:warning]).to be
    end

    # юзер пытается создать новую игру, не закончив старую
    it 'try to create second game' do
      # убедились что есть игра в работе
      expect(game_w_questions.finished?).to be_falsey

      # отправляем запрос на создание, убеждаемся что новых Game не создалось
      expect { post :create }.to change(Game, :count).by(0)

      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game).to be_nil

      # и редирект на страницу старой игры
      expect(response).to redirect_to(game_path(game_w_questions))
      expect(flash[:alert]).to be
    end

    # проверка метода #answer в случае неправильного ответа пользователя
    describe '#answer' do
      let(:wrong_answer) { %w[a b c d].reject \
        { |answer| answer == game_w_questions.current_game_question.correct_answer_key }.sample }

      # пользователь дал неправильный ответ
      context 'wrong answer' do
        it 'answers not correct' do
          # передаем параметр params[:letter]
          put :answer, id: game_w_questions.id, letter: wrong_answer

          game = assigns(:game)

          # игра должна быть закончена
          expect(game.finished?).to be true

          # должна зафейлиться
          expect(game.status).to eq :fail

          # уровень должен остаться прежним
          expect(game.current_level).to be 0

          # редиректим на страницу юзера
          expect(response).to redirect_to(user_path(user))
          
          # уведомление об окончании игры
          expect(flash[:alert]).to be
        end
      end
    end
  end
end
