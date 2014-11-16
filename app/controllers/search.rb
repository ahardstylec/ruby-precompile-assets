# require 'pathname'

AcHome::App.controllers :search do

	get :index do
		folders = current_account.get_folders
		@images = AC::FileUtilities.get_images folders
		render '/images/index'
	end

end