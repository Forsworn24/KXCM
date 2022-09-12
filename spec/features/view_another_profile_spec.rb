# Как и в любом тесте, подключаем помощник rspec-rails
require 'rails_helper'

RSpec.feature 'USER see another profile', type: :feature do
  
  # текущий пользователь
  let(:current_user) { create :user }

  # профиль просматриваемого пользователя
  let(:user) { create(:user, name: 'Александр', email: 'alex@yandex.ru') }

  # игры просматриваемого пользователя
  let!(:games) do
    [
      create(:game, user: user, id: 11, created_at: Time.zone.parse('2021.01.01, 11:11'),
                         finished_at: Time.zone.parse('2021.01.01, 11:33'), current_level: 11, prize: 10_000),
      create(:game, user: user, id: 22, created_at: Time.zone.parse('2022.02.02, 22:02'),
                         finished_at: Time.zone.parse('2022.02.02, 22:22'), current_level: 2, prize: 2000),
    ]
  end

  # логиним текущего пользователя
  before(:each) do
    login_as current_user
  end

  # пользователь заходит на страницу просматриваемого пользователя и видит его игры
  scenario 'successfully' do
    visit "/"
    click_link "Александр"

    expect(page).to have_current_path "/users/#{user.id}"
    expect(page).to have_content('Александр')

    expect(page).not_to have_button('Сменить имя и пароль')
    expect(page).to have_no_content('Сменить имя и пароль')

    expect(page).to have_content '11'
    expect(page).to have_content '01 янв., 11:11'
    expect(page).to have_content 'деньги'
    expect(page).to have_content '11'
    expect(page).to have_content '10 000 ₽'

    expect(page).to have_content '22'
    expect(page).to have_content '02 февр., 22:02'
    expect(page).to have_content 'деньги'
    expect(page).to have_content '2'
    expect(page).to have_content '2 000 ₽'
  end
end
