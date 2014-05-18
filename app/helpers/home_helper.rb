# Helper methods defined here can be accessed in any controller or view in the application

AcHome::App.helpers do
  # def simple_helper_method
  #  ...
  # end

  def icon_tag(icon, text="", classes=[])
    "<i class='fa fa-#{icon} #{classes.map{|c| "fa-#{c}"}.join(" ")}'>#{text}</i>".html_safe
  end

  def icon_tag_me(icon, text="", classes=[])
  	debugger if icon == 'sign-out'
    "<i class='fa fa-#{icon} #{classes.map{|c| "fa-#{c}"}.join(" ")}'>#{text}</i>".html_safe
  end

end
