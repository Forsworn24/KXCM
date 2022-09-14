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


  describe '#show' do
    context 'when anonymous' do
      it 'kick from #show' do
        get :show, id: game_w_questions.id

        expect(response.status).not_to eq 200
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be
      end

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

    context 'when registered user' do
      before { sign_in user }

      context 'and game owner' do
        # юзер создает игру
        it 'creates game' do
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
        it 'renders show template' do
          get :show, id: game_w_questions.id
          game = assigns(:game)

          expect(game.finished?).to be_falsey
          expect(game.user).to eq(user)
          expect(response.status).to eq 200

          expect(response).to render_template('show')
        end

        # пользователь ответил правильно на вопрос и контроллер это обработает
        it 'continues game' do
          put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key

          game = assigns(:game)

          expect(game.finished?).to be_falsey
          expect(game.current_level).to be > 0
          expect(response).to redirect_to(game_path(game))
          expect(flash.empty?).to be_truthy
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

        context 'play and use prompts' do

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
          
          # тест на обработку использования подсказки 50/50
          it 'uses fifty_fifty' do
            # сперва проверяем что в подсказках текущего вопроса пусто
            expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
            expect(game_w_questions.fifty_fifty_used).to be_falsey
            # фигачим запрос в контроллен с нужным типом
            put :help, id: game_w_questions.id, help_type: :fifty_fifty
            game = assigns(:game)
            # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
            expect(game.finished?).to be_falsey
            expect(game.fifty_fifty_used).to be_truthy
            # проверяем наличие подсказки
            expect(game.current_game_question.help_hash[:fifty_fifty]).to be
            # проверяем, что осталось только 2 ответа из 4, а также один из них является верным
            # в нашем случае верный ответ всегда будет - d
            expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq 2
            expect(game.current_game_question.help_hash[:fifty_fifty]).to include('d')
            expect(response).to redirect_to(game_path(game))
          end
        end

        # проверка метода #answer в случае неправильного ответа пользователя
        context 'and takes wrong answer' do
          let(:wrong_answer) { %w[a b c d].reject \
            { |answer| answer == game_w_questions.current_game_question.correct_answer_key }.sample }

          # пользователь дал неправильный ответ
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

      context 'and not game owner' do
        it 'not show alien game' do

          # создаем новую игру, юзер не прописан, будет создан фабрикой новый
          alien_game = create(:game_with_questions)
        
          # пробуем зайти на эту игру текущий залогиненным user
          get :show, id: alien_game.id
        
          expect(response.status).not_to eq(200) # статус не 200 ОК
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to be # во flash должен быть прописана ошибка
        end
      end
    end
  end
end
