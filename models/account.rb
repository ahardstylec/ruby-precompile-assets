require 'pathname'
#require 'fileutils'
# require 'dm-serializer'
require 'securerandom'

class Account
  include DataMapper::Resource
  include DataMapper::Validate
  attr_accessor :password, :password_confirmation

  # Properties
  property :id,               Serial
  property :username,         String
  property :name,             String
  property :surname,          String
  property :email,            String
  property :crypted_password, String, :length => 70
  property :role,             String
  property :attachment_token, String  

  # Validations
  validates_presence_of      :email, :role, :username
  validates_presence_of      :password,                          :if => :password_required
  validates_presence_of      :password_confirmation,             :if => :password_required
  validates_length_of        :password, :min => 4, :max => 40,   :if => :password_required
  validates_confirmation_of  :password,                          :if => :password_required
  validates_length_of        :email,    :min => 3, :max => 100
  validates_uniqueness_of    :email, :username,    :case_sensitive => false
  validates_format_of        :email,    :with => :email_address
  validates_format_of        :role,     :with => /[A-Za-z]/

  has n, :attachments
  has n, :shared_folders, child_key: [:owner_id]
  has n, :friends_folders, model: 'SharedFolder', child_key: [:friend_id]

  # Callbacks
  before :save, :encrypt_password
  before :save, :set_attachment_token
  after :create, :create_data_folder

  def create_dummy
    b= Account.create username: :b, name: "dasd", email: "dasd@asdas.de", password: "1233", password_confirmation: "1233", role: :member
  end

  ##
  # This method is for authentication purpose.
  #
  def self.authenticate(email, password)
    account = first(:conditions => ["lower(email) = lower(?)", email]) if email.present?
    account = first(username: email) if email.present?
    account && account.has_password?(password) ? account : nil
  end

  def set_attachment_token
    self.attachment_token = SecureRandom.urlsafe_base64
  end

  def create_data_folder
    FileUtils.mkdir_p data_path("first\ folder")
    FileUtils.cp File.join(Padrino.root, "data", "templates", "readme"), data_path
  end

  def data_path sub_path=""
    File.join(File.join(Padrino.root, "data", username), sub_path)
  end

  def data_folder
    return @data_folder if @data_folder
    @data_folder = AcFile.new(self.data_path)
    @data_folder
  end

  def get_folders
    friendsfolders = self.friends_folders.map{|sf| AcFile.new(sf.path) }
    [data_folder] | friendsfolders.select do |sharedfolder|
      friendsfolders.reject{|sf| sf == sharedfolder || sf.include?(sharedfolder) }
    end
  end

  def share(file, friend, permission="read")
    file = file.is_a?(AcFile) ? file : AcFile.new(file)
    if self.data_folder.include?(file) || file.path == self.data_folder.path
      sf = SharedFolder.new(friend: friend, path: file.path, permission: permission)
      self.shared_folders<< sf
      sf.save
      sf
    else
      nil
    end
  end

  ##
  # This method is used by AuthenticationHelper
  #
  def self.find_by_id(id)
    get(id) rescue nil
  end

  def has_password?(password)
    ::BCrypt::Password.new(crypted_password) == password
  end

  def can_change_file(file)
    spath = Pathname.new(self.data_path).realpath.to_s
    opath = Pathname.new(file).realpath.to_s
    !opath.gsub!(/^#{spath}/,'').nil?
  end

  def allowed_to_change_files(*files)
    !files.reject{|file| self.can_change_file(file) }.any?
  end

  def allowed_to_visit_files(*files)
    true
  end

  def to_json(*arguments)
    hash= {}
    hash[:name]= self.name
    hash[:username] = self.username
    hash[:id] = self.id
    hash[:shared_folders] =self.shared_folders
    hash[:friends_folders] =self.shared_folders
    hash.to_json
  end

  private

  def password_required
    crypted_password.blank? || password.present?
  end

  def encrypt_password
    self.crypted_password = ::BCrypt::Password.create(password) if password.present?
  end
end
