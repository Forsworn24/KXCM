# Как и в любом тесте, подключаем помощник rspec-rails
require 'rails_helper'

RSpec.feature 'USER create a game', type: :feature do
  # Готовим базу: создаём пользователя
  let(:user) { create :user }

  # А также 15 вопросов с разными уровнями сложности
  # Обратите внимание, текст вопроса и вариантов ответа
  # здесь важен — их мы потом будем проверять
  let!(:questions) do
    (0..14).to_a.map do |i|
      create(
        :question, level: i,
        text: "Когда была куликовская битва номер #{i}?",
        answer1: '1380', answer2: '1381', answer3: '1382', answer4: '1383'
      )
    end
  end

  before(:each) do
    login_as user
  end

  scenario 'successfully' do
    visit '/'

    click_link 'Новая игра'

    # Ожидаем, что попадем на нужный url
    expect(page).to have_current_path '/games/1'

    # Ожидаем, что на экране вопрос игры (который мы добавили в БД)
    # Берём самый простой (0)
    expect(page).to have_content 'Когда была куликовская битва номер 0?'

    # Ожидаем, что на экране будут варианты ответа на вопрос
    expect(page).to have_content '1380'
    expect(page).to have_content '1381'
    expect(page).to have_content '1382'
    expect(page).to have_content '1383'
  end
end
