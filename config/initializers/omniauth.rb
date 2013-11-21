OmniAuth.config.logger = Rails.logger

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, '682158981819004', '6add046c4519989853b9c512f012c0da'
end