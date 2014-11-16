AcHome::App.controllers :home do

  before :index, :refresh_sidebar do
    @file_hirarchy = current_account.get_folders
  end

  get :index, :map => '/' do
    render 'index'
  end

  get :refresh_sidebar, provides: :json do
    {data: @file_hirarchy}.to_json
  end

end