class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable, and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2, :github]

  has_one_attached :profile_picture
  has_many :subscriptions, dependent: :destroy

  attr_accessor :otp_code

  before_save :normalize_phone_number

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      
      # Optionally attach the profile picture if available
      if auth.info.image
        image_url = URI.parse(auth.info.image)
        user.profile_picture.attach(io: StringIO.new(Net::HTTP.get(URI(image_url))), filename: 'profile_picture.jpg')
      end

      # Handle different attributes for different providers
      if auth.provider == 'github'
        user.username = auth.info.nickname # Example for GitHub
      elsif auth.provider == 'google_oauth2'
        user.full_name = auth.info.name # Example for Google
      end
    end
  end

  def send_otp_code
    TwilioService.new.send_otp(phone_number, otp_code)
  end

  def verify_otp_code(input_code)
    self.otp_code == input_code
  end

  private

  def normalize_phone_number
    self.phone_number = PhonyRails.normalize_number(self.phone_number, default_country_code: 'US')
  end
end
