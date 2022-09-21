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

  describe '#create' do
    context 'when anonymous' do
      context 'try to create a game' do
        before { post :create }

        it 'game not created' do
          game = assigns(:game)
          expect(game).to be_nil
        end

        it 'stop creating the game and redirect to login' do
          expect(response).to redirect_to(new_user_session_path)
        end

        it 'displays alert' do
          expect(flash[:alert]).to be
        end

        it 'response not 200' do
          expect(response.status).not_to eq 200
        end
      end
    end

    context 'when registered user' do
      before { sign_in user }

      context 'and game owner' do
        before { generate_questions(60) }

        context 'creates a game' do
          before { post :create }

          it 'the game has begun' do
            game = assigns(:game)
            expect(game.finished?).to be_falsey
          end

          it 'the user is himself' do
            game = assigns(:game)
            expect(game.user).to eq(user)
          end

          it 'redirect to game page' do
            game = assigns(:game)
            expect(response).to redirect_to game_path(game)
          end

          it 'game start notification' do
            expect(flash[:notice]).to be
          end
        end

        context 'creates another game after the old one' do
          it 'new game not created and nil' do
            expect(game_w_questions.finished?).to be_falsey
            expect { post :create }.to change(Game, :count).by(0)
            game = assigns(:game)
            expect(game).to be_nil
          end

          it 'redirect to old game' do
            expect(game_w_questions.finished?).to be_falsey
            expect { post :create }.to change(Game, :count).by(0)
            game = assigns(:game)
            expect(response).to redirect_to(game_path(game_w_questions))
          end

          it 'alert exits' do
            expect(game_w_questions.finished?).to be_falsey
            expect { post :create }.to change(Game, :count).by(0)
            game = assigns(:game)
            expect(flash[:alert]).to be
          end
        end
      end
    end
  end

  describe '#answer' do
    context 'trying to answer a question' do
      before { put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key }

      it 'game not created' do
        game = assigns(:game)
        expect(game).to be_nil
      end

      it 'stop creating the game and redirect to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'displays alert' do
        expect(flash[:alert]).to be
      end

      it 'response not 200' do
        expect(response.status).not_to eq 200
      end
    end

    context 'when registered user' do
      before { sign_in user }

      context 'and game owner' do
        before { generate_questions(60) }

        context 'answers the questions of his game trythy' do
          before { put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key }
        
          it 'the game continues' do
            game = assigns(:game)
            expect(game.finished?).to be_falsey
          end

          it 'level of current game > 0' do
            game = assigns(:game)
            expect(game.current_level).to be > 0
          end

          it 'response of redirect to game page is 200' do
            game = assigns(:game)
            expect(response).to redirect_to(game_path(game))
          end

          it 'no notification' do
            expect(flash.empty?).to be_truthy
          end
        end
      end
    end
  end

  describe '#take_money' do
    context 'when anonymous' do
      context 'trying to get money' do
        before do
           put :take_money, id: game_w_questions.id
           game_w_questions.update_attribute(:current_level, 2)
        end

        it 'game not created' do
          game = assigns(:game)
          expect(game).to be_nil
        end

        it 'stop creating the game and redirect to login' do
          expect(response).to redirect_to(new_user_session_path)
        end

        it 'displays alert' do
          expect(flash[:alert]).to be
        end

        it 'response not 200' do
          expect(response.status).not_to eq 200
        end
      end
    end

    context 'when registered user' do
      before { sign_in user }

      context 'and game owner' do
        before { generate_questions(60) }

        context 'takes the money and ends the game' do
          before do
            game_w_questions.update_attribute(:current_level, 2)
            put :take_money, id: game_w_questions.id
          end

          it 'game finished' do
            game = assigns(:game)
            expect(game.finished?).to be_truthy
          end

          it 'price is 200' do
            game = assigns(:game)
            expect(game.prize).to eq(200)
          end

          it 'and changed in base' do
            user.reload
            expect(user.balance).to eq(200)
          end

          it 'response of redirect to changed user path is 200' do
            user.reload
            expect(response).to redirect_to(user_path(user))
          end

          it 'notification of reload user exitst' do
            user.reload
            expect(flash[:warning]).to be
          end
        end
      end
    end
  end

  describe '#show' do
    context 'when anonymous' do
      context 'try to see a game' do
        before { get :show, id: game_w_questions.id }

        it 'stop watching the game and redirect to login' do
          expect(response).to redirect_to(new_user_session_path)
        end

        it 'displays alert' do
          expect(flash[:alert]).to be
        end

        it 'response not 200' do
          expect(response.status).not_to eq 200
        end
      end
    end

    context 'when registered user' do
      before { sign_in user }

      context 'and game owner' do
        before { generate_questions(60) }

        context 'sees his game' do
          before { get :show, id: game_w_questions.id }

          it 'the game continues' do
            game = assigns(:game)
            expect(game.finished?).to be_falsey
          end

          it 'the user is himself' do
            game = assigns(:game)
            expect(game.user).to eq(user)
          end

          it 'response 200' do
            expect(response.status).to eq 200
          end

          it 'render show template' do
            expect(response).to render_template('show')
          end
        end
      end

      context 'and not game owner' do
        before { get :show, id: alien_game.id }

        it 'response of show alien game is not 200' do
          expect(response.status).not_to eq(200)
        end

        it 'redirect to root path' do
          expect(response).to redirect_to(root_path)
        end

        it 'error message' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#help' do
    context 'user use audience help' do
      before do
        sign_in user
        put :help, id: game_w_questions.id, help_type: :audience_help
      end
      
      it 'hint used and game not finished' do
        game = assigns(:game)
        expect(game.finished?).to be_falsey
      end

      it 'hint used' do
        game = assigns(:game)
        expect(game.audience_help_used).to be_truthy
      end

      it 'hint used' do
        game = assigns(:game)
        expect(game.current_game_question.help_hash[:audience_help]).to be
      end

      it 'keys of hint' do
        game = assigns(:game)
        expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      end

      it 'after use hint redircted to game path' do
        game = assigns(:game)
        expect(response).to redirect_to(game_path(game))
      end
    end

    context 'user use fifty-fifty' do
      before do
        sign_in user
        put :help, id: game_w_questions.id, help_type: :fifty_fifty
      end
      
      it 'hint used and game not finished' do
        game = assigns(:game)
        expect(game.finished?).to be_falsey
      end

      it 'hint used' do
        game = assigns(:game)
        expect(game.fifty_fifty_used).to be_truthy
      end

      it 'hint used' do
        game = assigns(:game)
        expect(game.current_game_question.help_hash[:fifty_fifty]).to be
      end

      it 'keys of hint includes right variant d' do
        game = assigns(:game)
        expect(game.current_game_question.help_hash[:fifty_fifty]).to include('d')
      end

      it 'keys of hint has 2 keys' do
        game = assigns(:game)
        expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq 2
      end

      it 'after use hint redircted to game path' do
        game = assigns(:game)
        expect(response).to redirect_to(game_path(game))
      end
    end
  end
end
