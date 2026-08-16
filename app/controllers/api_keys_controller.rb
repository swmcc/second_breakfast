class ApiKeysController < ApplicationController
  before_action :authenticate_user!

  def create
    api_key = current_user.api_keys.new(api_key_params)

    if api_key.save
      # Flash is the one-time channel: gone after the next request, so the
      # raw token can never be re-rendered.
      flash[:new_api_key_token] = api_key.token
      flash[:new_api_key_name] = api_key.name
      redirect_to account_path
    else
      redirect_to account_path, alert: api_key.errors.full_messages.to_sentence
    end
  end

  def destroy
    current_user.api_keys.find(params[:id]).revoke!
    redirect_to account_path, notice: "API key revoked"
  end

  private

  def api_key_params
    params.require(:api_key).permit(:name)
  end
end
