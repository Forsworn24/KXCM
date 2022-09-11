require 'rails_helper'

# Тест на шаблон users/show.html.erb

RSpec.describe 'users/show', type: :view do
  let(:user) { create(:user, name: "Петя", balance: 13000) }
  let(:game) { build_stubbed(:game, id: 313, created_at: Time.now, current_level: 10, prize: 1000) }

  # как пользователь видит свою страницу
  context 'user sees his page' do
    before(:each) do
      assign(:user, user)
      assign(:game, game)

      sign_in user
      stub_template 'users/_game.html.erb' => 'Отрисованный фрагмент с игрой залогиненного пользователя'

      render
    end

    # пользователь видит свое имя
    it 'user sees his name' do
      expect(rendered).to match "Петя"
    end

    # пользователь видит смену имени и  пароля
    it 'user dont sees change password button' do
      expect(rendered).to match 'Сменить имя и пароль'
    end

    # пользователь видит страницу другого пользователя с играми
    it 'user see another user page with his games' do
      render partial: 'users/game'
      expect(rendered).to have_content 'Отрисованный фрагмент с игрой залогиненного пользователя'
    end
  end

  # как пользователь видит страницу другого пользователя 
  context 'user sees another users page' do
    before(:each) do
      assign(:user, build_stubbed(:user, name: "Петя", balance: 13000))
      assign(:game, game)
      stub_template 'users/_game.html.erb' => 'Отрисованный фрагмент с игрой'

      render
    end

    # пользователь видит имя
    it 'user sees his name' do
      expect(rendered).to match "Петя"
    end

    # пользователь не видит смену имени и пароля
    it 'user dont sees change password button' do
      expect(rendered).not_to match 'Сменить имя и пароль'
    end

    # пользователь видит страницу другого пользователя с играми
    it 'user see another user page with his games' do
      render partial: 'users/game'
      expect(rendered).to have_content 'Отрисованный фрагмент с игрой'
    end
  end

end
